use actix_web::{get, web, HttpResponse, Responder};
use crate::models::{AppState, RandQuery};
use crate::utils::{select_random_from_bag, select_random_from_list, select_random_words, contains_only_letters, count_vowels_consonants};
use rand::seq::SliceRandom;

#[get("/rand/langs/{lang}/letter")]
pub async fn rand_letter(
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
pub async fn rand_vowel(
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
pub async fn rand_consonant(
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
pub async fn rand_unicorn(
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
pub async fn rand_word(
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
