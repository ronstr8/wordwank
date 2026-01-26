use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};
use std::collections::{HashSet, HashMap};
use std::fs::File;
use std::io::{self, BufRead};
use clap::{Command, Arg};
use log::{info, warn};
use env_logger;
use std::fs::OpenOptions;
use rand::seq::SliceRandom;

// Struct to hold multiple language word lists and pre-computed distributions
struct AppState {
    word_lists: HashMap<String, HashSet<String>>,
    supported_langs: Vec<String>,
    letter_bags: HashMap<String, HashMap<char, usize>>,          // Computed tile distribution (bag)
    vowel_sets: HashMap<String, Vec<char>>,                      // Vowels per language
    consonant_sets: HashMap<String, Vec<char>>,                  // Consonants per language
    unicorn_sets: HashMap<String, Vec<char>>,                    // Rarest 2 letters per language
}

// Function to initialize logging
fn init_logging(log_file: Option<&String>) {
    if let Some(file) = log_file {
        let log_output = OpenOptions::new()
            .create(true)
            .append(true)
            .open(file)
            .expect("Failed to open log file");

        env_logger::Builder::new()
            .target(env_logger::Target::Pipe(Box::new(log_output)))
            .init();
    } else {
        env_logger::init();
    }
}

// Function to load words from a file into a HashSet
// Function to load words from a YAML file (expects a list of strings)
fn load_words(file_path: &str, max_len: usize) -> io::Result<HashSet<String>> {
    let file = File::open(file_path)?;
    let reader = io::BufReader::new(file);
    
    let mut words = HashSet::new();
    for line in reader.lines() {
        let line = line?;
        let word = line.trim();
        if !word.is_empty() && word.len() <= max_len {
            words.insert(word.to_uppercase());
        }
    }

    Ok(words)
}

fn load_filtered_words(base_dir: &str, lang: &str, max_len: usize) -> HashSet<String> {
    let lang_dir = format!("{}/words/{}", base_dir, lang);
    
    let valid_path = format!("{}/lexicon.txt", lang_dir);
    let custom_path = format!("{}/insertions.txt", lang_dir);
    let censored_path = format!("{}/deletions.txt", lang_dir);

    let mut words = load_words(&valid_path, max_len)
        .unwrap_or_else(|_| {
            warn!("Failed to load main lexicon for {} at {}.", lang, valid_path);
            HashSet::new()
        });

    if let Ok(custom) = load_words(&custom_path, max_len) {
        info!("Inserted {} words into {} lexicon.", custom.len(), lang);
        words.extend(custom);
    }

    if let Ok(censored) = load_words(&censored_path, max_len + 100) { // deletions don't need length filter
        info!("Deleted {} words from {} lexicon.", censored.len(), lang);
        for word in censored {
            words.remove(&word);
        }
    }

    info!("Total valid words for {} (max_len {}): {}", lang, max_len, words.len());
    words
}

// Function to calculate letter frequency distribution from a word set
fn calculate_distribution_from_set(words: &HashSet<String>) -> HashMap<char, usize> {
    let mut freq = HashMap::new();
    for word in words {
        for c in word.chars() {
            if c.is_alphabetic() {
                *freq.entry(c).or_insert(0) += 1;
            }
        }
    }
    freq
}

// Function to compute tile bag from letter frequency
fn compute_tile_bag(freq: &HashMap<char, usize>, total_tiles: usize) -> HashMap<char, usize> {
    let total_chars: usize = freq.values().sum();
    if total_chars == 0 {
        return HashMap::new();
    }

    let mut tiles = HashMap::new();
    tiles.insert('_', 2); // Always include 2 blanks

    let mut remaining_tiles: isize = (total_tiles as isize) - 2;
    let pool_size = remaining_tiles as f64;
    
    // First pass: Proportional allocation with floor of 1
    for (&c, &count) in freq {
        let proportion = (count as f64) / (total_chars as f64);
        let mut tile_count = (proportion * pool_size).round() as usize;
        if tile_count == 0 { tile_count = 1; }
        
        tiles.insert(c, tile_count);
        remaining_tiles -= tile_count as isize;
    }

    // Second pass: Adjust to exactly total_tiles if we have leftovers or overshoots
    if remaining_tiles > 0 {
        // Give leftovers to common letters
        let mut sorted_letters: Vec<_> = freq.keys().cloned().collect();
        sorted_letters.sort_by_key(|&c| std::cmp::Reverse(freq[&c]));
        for i in 0..(remaining_tiles as usize) {
            if let Some(&c) = sorted_letters.get(i % sorted_letters.len()) {
                *tiles.entry(c).or_insert(0) += 1;
            }
        }
    }

    tiles
}

// Function to classify letters into vowels, consonants, and unicorns
fn classify_letters(freq: &HashMap<char, usize>, lang: &str) -> (Vec<char>, Vec<char>, Vec<char>) {
    // Define vowels for each language
    let vowels: Vec<char> = match lang {
        "es" => vec!['A', 'E', 'I', 'O', 'U', 'Á', 'É', 'Í', 'Ó', 'Ú'],
        "fr" => vec!['A', 'E', 'I', 'O', 'U', 'Y', 'À', 'Â', 'Æ', 'Ç', 'É', 'È', 'Ê', 'Ë', 'Î', 'Ï', 'Ô', 'Œ', 'Ù', 'Û', 'Ü', 'Ÿ'],
        "de" => vec!['A', 'E', 'I', 'O', 'U', 'Ä', 'Ö', 'Ü'],
        _ => vec!['A', 'E', 'I', 'O', 'U'], // Default to English
    };

    // Identify unicorns (2 rarest letters)
    let mut sorted_letters: Vec<_> = freq.keys().cloned().collect();
    sorted_letters.sort_by_key(|&c| freq[&c]);
    let unicorns: Vec<char> = sorted_letters.iter().take(2).cloned().collect();

    // Classify consonants (all letters not vowels)
    let vowel_set: HashSet<char> = vowels.iter().cloned().collect();
    let consonants: Vec<char> = freq.keys()
        .filter(|&&c| !vowel_set.contains(&c))
        .cloned()
        .collect();

    (vowels, consonants, unicorns)
}



#[derive(serde::Serialize)]
struct LangInfo {
    name: String,
    code: String,
}

#[get("/langs")]
async fn get_langs(data: web::Data<AppState>) -> impl Responder {
    let langs: Vec<LangInfo> = data.supported_langs.iter().map(|code| {
        let name = match code.as_str() {
            "en" => "English",
            "es" => "Español",
            "fr" => "Français",
            "de" => "Deutsch",
            _ => code.as_str(),
        }.to_string();
        LangInfo { name, code: code.clone() }
    }).collect();

    HttpResponse::Ok().json(langs)
}

#[derive(serde::Serialize)]
struct ConfigResponse {
    tiles: HashMap<char, usize>,
    unicorns: HashMap<char, usize>,
    vowels: Vec<char>,
    bag: HashMap<char, usize>, // The complete tile bag distribution
}

#[get("/config/{lang}")]
async fn get_config(
    data: web::Data<AppState>,
    path: web::Path<String>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    
    // Retrieve pre-computed values from AppState
    let bag = match data.letter_bags.get(&lang) {
        Some(b) => b.clone(),
        None => return HttpResponse::BadRequest().finish(),
    };

    let vowels = match data.vowel_sets.get(&lang) {
        Some(v) => v.clone(),
        None => return HttpResponse::BadRequest().finish(),
    };

    let unicorns = match data.unicorn_sets.get(&lang) {
        Some(u) => {
            // Convert unicorn letters to HashMap with standard value of 10
            u.iter().map(|&c| (c, 10)).collect::<HashMap<char, usize>>()
        },
        None => return HttpResponse::BadRequest().finish(),
    };

    // tiles is same as bag for backward compatibility
    let tiles = bag.clone();

    info!("Generated {} config with {} tiles, {} unicorns, and {} vowels", 
          lang, tiles.values().sum::<usize>(), unicorns.len(), vowels.len());

    HttpResponse::Ok().json(ConfigResponse {
        tiles,
        unicorns,
        vowels,
        bag,
    })
}

#[get("/word/{lang}/{word}")]
async fn check_word_lang(
    data: web::Data<AppState>,
    path: web::Path<(String, String)>,
) -> impl Responder {
    let (lang, word) = path.into_inner();
    let words = match data.word_lists.get(&lang.to_lowercase()) {
        Some(w) => w,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };

    let is_valid = words.contains(&word.to_uppercase());

    if !is_valid {
        info!("Invalid word queried ({}): {}", lang, word.to_lowercase());
        return HttpResponse::NotFound().finish();
    }

    info!("Valid word queried ({}): {}", lang, word.to_uppercase());
    HttpResponse::Ok().body(format!("Valid word: {}", word.to_uppercase()))
}

// Backward compatibility
#[get("/word/{word}")]
async fn check_word(
    data: web::Data<AppState>,
    word: web::Path<String>,
) -> impl Responder {
    let word = word.into_inner();
    let words = match data.word_lists.get("en") {
        Some(w) => w,
        None => return HttpResponse::InternalServerError().finish(),
    };

    let is_valid = words.contains(&word.to_uppercase());
    if !is_valid { return HttpResponse::NotFound().finish(); }

    HttpResponse::Ok().body(format!("Valid word: {}", word.to_uppercase()))
}

#[get("/validate/{lang}/{word}")]
async fn validate_word_lang(
    data: web::Data<AppState>,
    path: web::Path<(String, String)>,
) -> impl Responder {
    let (lang, word) = path.into_inner();
    let words = match data.word_lists.get(&lang.to_lowercase()) {
        Some(w) => w,
        None => return HttpResponse::BadRequest().finish(),
    };

    if words.contains(&word.to_uppercase()) {
        HttpResponse::Ok().finish()
    } else {
        HttpResponse::NotFound().finish()
    }
}

#[get("/validate/{word}")]
async fn validate_word(
    data: web::Data<AppState>,
    word: web::Path<String>,
) -> impl Responder {
    let word = word.into_inner();
    let words = match data.word_lists.get("en") {
        Some(w) => w,
        None => return HttpResponse::InternalServerError().finish(),
    };

    if words.contains(&word.to_uppercase()) {
        HttpResponse::Ok().finish()
    } else {
        HttpResponse::NotFound().finish()
    }
}


// Helper function to select random items from a weighted bag (HashMap)
fn select_random_from_bag(bag: &HashMap<char, usize>, count: usize) -> Vec<char> {
    let mut rng = rand::thread_rng();
    let mut pool: Vec<char> = Vec::new();
    
    // Create a pool with weighted distribution
    for (&letter, &freq) in bag {
        if letter != '_' { // Exclude blanks from random selection
            for _ in 0..freq {
                pool.push(letter);
            }
        }
    }
    
    // Randomly select from pool with replacement
    (0..count).map(|_| {
        pool.choose(&mut rng).copied().unwrap_or('A')
    }).collect()
}

// Helper function to select random items from a list
fn select_random_from_list(list: &[char], count: usize) -> Vec<char> {
    let mut rng = rand::thread_rng();
    (0..count).map(|_| {
        list.choose(&mut rng).copied().unwrap_or('A')
    }).collect()
}

// Helper function to select random words from a word set
fn select_random_words(words: &HashSet<String>, count: usize) -> Vec<String> {
    let mut rng = rand::thread_rng();
    let words_vec: Vec<&String> = words.iter().collect();
    (0..count).map(|_| {
        words_vec.choose(&mut rng).map(|s| (*s).clone()).unwrap_or_else(|| "WORD".to_string())
    }).collect()
}

// Query parameter struct for random endpoints
#[derive(serde::Deserialize)]
struct RandQuery {
    count: Option<usize>,
    letters: Option<String>,
    min_vowels: Option<usize>,
    min_consonants: Option<usize>,
}

fn contains_only_letters(word: &str, letters: &str) -> bool {
    let word_upper = word.to_uppercase();
    let mut letter_counts: HashMap<char, usize> = HashMap::new();
    
    for ch in letters.to_uppercase().chars() {
        if ch.is_alphabetic() {
            *letter_counts.entry(ch).or_insert(0) += 1;
        }
    }
    
    let mut word_letters: HashMap<char, usize> = HashMap::new();
    for ch in word_upper.chars() {
        if ch.is_alphabetic() {
            *word_letters.entry(ch).or_insert(0) += 1;
        }
    }
    
    word_letters.iter().all(|(ch, &letters_used)| {
        letters_used <= letter_counts.get(ch).copied().unwrap_or(0)
    })
}

// Helper function to count vowels and consonants in a word
fn count_vowels_consonants(word: &str, vowels: &[char]) -> (usize, usize) {
    let word_upper = word.to_uppercase();
    let vowel_set: HashSet<char> = vowels.iter().map(|c| c.to_uppercase().next().unwrap()).collect();
    
    let mut vowel_count = 0;
    let mut consonant_count = 0;
    
    for ch in word_upper.chars() {
        if ch.is_alphabetic() {
            if vowel_set.contains(&ch) {
                vowel_count += 1;
            } else {
                consonant_count += 1;
            }
        }
    }
    
    (vowel_count, consonant_count)
}

#[get("/rand/langs/{lang}/letter")]
async fn rand_letter(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let bag = match data.letter_bags.get(&lang) {
        Some(b) => b,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    let letters = select_random_from_bag(bag, count);
    let output = letters.iter().map(|c| c.to_string()).collect::<Vec<_>>().join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}

#[get("/rand/langs/{lang}/vowel")]
async fn rand_vowel(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let vowels = match data.vowel_sets.get(&lang) {
        Some(v) => v,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    let selected = select_random_from_list(vowels, count);
    let output = selected.iter().map(|c| c.to_string()).collect::<Vec<_>>().join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}

#[get("/rand/langs/{lang}/consonant")]
async fn rand_consonant(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let consonants = match data.consonant_sets.get(&lang) {
        Some(c) => c,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    let selected = select_random_from_list(consonants, count);
    let output = selected.iter().map(|c| c.to_string()).collect::<Vec<_>>().join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}

#[get("/rand/langs/{lang}/unicorn")]
async fn rand_unicorn(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let unicorns = match data.unicorn_sets.get(&lang) {
        Some(u) => u,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    let selected = select_random_from_list(unicorns, count);
    let output = selected.iter().map(|c| c.to_string()).collect::<Vec<_>>().join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}

#[get("/rand/langs/{lang}/word")]
async fn rand_word(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let words = match data.word_lists.get(&lang) {
        Some(w) => w,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };
    
    // Get language-specific vowels for constraint validation
    let vowels = data.vowel_sets.get(&lang)
        .map(|v| v.as_slice())
        .unwrap_or(&['A', 'E', 'I', 'O', 'U']);
    
    let mut selected = Vec::new();
    let has_letters_constraint = query.letters.is_some();
    let has_rack_constraints = query.min_vowels.is_some() || query.min_consonants.is_some();
    
    if has_letters_constraint || has_rack_constraints {
        let mut rng = rand::thread_rng();
        let words_vec: Vec<&String> = words.iter().collect();
        let retries = 500; // Hardcoded for performance and security
        
        for _ in 0..count {
            for _ in 0..retries {
                if let Some(word) = words_vec.choose(&mut rng) {
                    let mut valid = true;
                    
                    // Check letters constraint
                    if let Some(available_letters) = &query.letters {
                        if !contains_only_letters(word, available_letters) {
                            valid = false;
                        }
                    }
                    
                    // Check vowel/consonant constraints
                    if valid && has_rack_constraints {
                        let (vowel_count, consonant_count) = count_vowels_consonants(word, vowels);
                        
                        if let Some(min_v) = query.min_vowels {
                            if vowel_count < min_v {
                                valid = false;
                            }
                        }
                        
                        if let Some(min_c) = query.min_consonants {
                            if consonant_count < min_c {
                                valid = false;
                            }
                        }
                    }
                    
                    if valid {
                        selected.push((*word).clone());
                        break;
                    }
                }
            }
        }
    } else {
        selected = select_random_words(words, count);
    }

    let output = selected.join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}


#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let matches = Command::new("wordd")
        .version("1.3")
        .author("Ron Straight <straightre@gmail.com>")
        .about("Polyglot word validity and lookup service")

        .arg(
            Arg::new("listen-host")
                .long("listen-host")
                .num_args(1)
                .default_value("0.0.0.0:2345")
                .help("Specify the listen address (e.g., 0.0.0.0:2345)"),
        )
        .arg(
            Arg::new("log-file")
                .long("log-file")
                .num_args(1)
                .help("Specify a log file path (if omitted, logs to stderr)"),
        )
        .arg(
            Arg::new("share-dir")
                .long("share-dir")
                .num_args(1)
                .default_value("./share")
                .help("Directory containing the word files"),
        )
        .arg(
            Arg::new("langs")
                .long("langs")
                .num_args(1)
                .default_value("en,es,fr")
                .help("Comma-separated list of languages to support"),
        )
        .arg(
            Arg::new("total-tiles")
                .long("total-tiles")
                .num_args(1)
                .default_value("100")
                .help("Total size of the tile bag (including 2 blanks)"),
        )
        .arg(
            Arg::new("rack-size")
                .long("rack-size")
                .env("DEFAULT_RANDOM_WORD_LETTER_COUNT")
                .num_args(1)
                .default_value("7")
                .help("Maximum word length (rack size)"),
        )
        .get_matches();


    let listen_host = matches
        .get_one::<String>("listen-host")
        .expect("listen-host argument must always have a default value")
        .clone();
    let log_file = matches.get_one::<String>("log-file");
    let share_dir = matches.get_one::<String>("share-dir").unwrap();
    let langs_str = matches.get_one::<String>("langs").unwrap();
    let total_tiles = matches
        .get_one::<String>("total-tiles")
        .unwrap()
        .parse::<usize>()
        .unwrap_or(100);
    let rack_size = matches
        .get_one::<String>("rack-size")
        .unwrap()
        .parse::<usize>()
        .unwrap_or(7);

    init_logging(log_file);

    let mut word_lists = HashMap::new();
    let mut supported_langs = Vec::new();
    let mut letter_bags = HashMap::new();
    let mut vowel_sets = HashMap::new();
    let mut consonant_sets = HashMap::new();
    let mut unicorn_sets = HashMap::new();

    for lang in langs_str.split(',') {
        let lang = lang.trim();
        info!("Loading word list for language: {} (max_len: {})", lang, rack_size);
        let words = load_filtered_words(share_dir, lang, rack_size);
        
        // Calculate letter distribution directly from the filtered in-memory set
        let freq = calculate_distribution_from_set(&words);
        info!("Calculated letter distribution for {} ({} unique letters, from {} words)", lang, freq.len(), words.len());
        
        // Compute tile bag
        let bag = compute_tile_bag(&freq, total_tiles);
        info!("Computed tile bag for {} ({} total tiles)", lang, bag.values().sum::<usize>());
        
        // Classify letters
        let (vowels, consonants, unicorns) = classify_letters(&freq, lang);
        info!("Classified letters for {}: {} vowels, {} consonants, {} unicorns", 
              lang, vowels.len(), consonants.len(), unicorns.len());
        
        // Store all pre-computed data
        word_lists.insert(lang.to_lowercase(), words);
        supported_langs.push(lang.to_lowercase());
        letter_bags.insert(lang.to_lowercase(), bag);
        vowel_sets.insert(lang.to_lowercase(), vowels);
        consonant_sets.insert(lang.to_lowercase(), consonants);
        unicorn_sets.insert(lang.to_lowercase(), unicorns);
    }

    let state = AppState {
        word_lists,
        supported_langs,
        letter_bags,
        vowel_sets,
        consonant_sets,
        unicorn_sets,
    };
    let shared_state = web::Data::new(state);

    HttpServer::new(move || {
        App::new()
            .app_data(shared_state.clone())
            .service(get_langs)
            .service(get_config)
            .service(check_word_lang)
            .service(check_word)
            .service(validate_word_lang)
            .service(validate_word)
            .service(rand_letter)
            .service(rand_vowel)
            .service(rand_consonant)
            .service(rand_unicorn)
            .service(rand_word)
    })
    .bind(("0.0.0.0", 2345))?
    .run()
    .await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_count_vowels_consonants_english() {
        let english_vowels = vec!['A', 'E', 'I', 'O', 'U'];
        
        let (v, c) = count_vowels_consonants("hello", &english_vowels);
        assert_eq!(v, 2); // e, o
        assert_eq!(c, 3); // h, l, l
        
        let (v, c) = count_vowels_consonants("AEIOU", &english_vowels);
        assert_eq!(v, 5);
        assert_eq!(c, 0);
        
        let (v, c) = count_vowels_consonants("bcdfg", &english_vowels);
        assert_eq!(v, 0);
        assert_eq!(c, 5);
    }

    #[test]
    fn test_count_vowels_consonants_spanish() {
        let spanish_vowels = vec!['A', 'E', 'I', 'O', 'U'];
        
        let (v, c) = count_vowels_consonants("hola", &spanish_vowels);
        assert_eq!(v, 2); // o, a
        assert_eq!(c, 2); // h, l
    }

    #[test]
    fn test_count_vowels_consonants_with_accents() {
        let french_vowels = vec!['A', 'E', 'I', 'O', 'U', 'Y'];
        
        // Test basic vowel counting
        let (v, c) = count_vowels_consonants("bonjour", &french_vowels);
        assert_eq!(v, 3); // o, o, u
        assert_eq!(c, 4); // b, n, j, r
    }

    #[test]
    fn test_contains_only_letters() {
        // Word can be formed from available letters
        assert!(contains_only_letters("hello", "helloworld")); // has all letters needed
        assert!(contains_only_letters("HELLO", "helloworld")); // case insensitive
        assert!(contains_only_letters("hello", "HELLOWORLD")); // case insensitive
        
        // Word cannot be formed - missing letters
        assert!(!contains_only_letters("hello", "hel")); // missing 'o' and extra 'l'
        assert!(!contains_only_letters("hello", "xyz")); // completely wrong letters
        
        // Word can be formed - exact match
        assert!(contains_only_letters("hello", "hello")); // exact letters
        assert!(contains_only_letters("hello", "ollhe")); // same letters, different order
    }

    #[test]
    fn test_contains_only_letters_duplicates() {
        // Word requires 2 l's, available letters have 2 l's
        assert!(contains_only_letters("hello", "hheelllloo")); // more than enough
        
        // Word requires 2 a's, available letters have 2 a's
        assert!(contains_only_letters("aardvark", "aardvarkxyz")); // has enough
        
        // Word requires 2 l's, but only 1 'l' available
        assert!(!contains_only_letters("hello", "hewoxrld")); // only 1 'l', needs 2
        
        // Word requires 3 l's, but only 2 available
        assert!(!contains_only_letters("llll", "ll")); // needs 4, only has 2
    }
}
