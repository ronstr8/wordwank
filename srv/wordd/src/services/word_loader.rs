use std::collections::{HashSet, HashMap};
use std::fs::File;
use std::io::{self, BufRead};
use log::{info, warn};

use crate::models::Word;
use crate::utils::compute_signature;

/// Load words from a plain text file (one word per line)
pub fn load_words(file_path: &str, max_len: usize) -> io::Result<HashSet<String>> {
    let file = File::open(file_path)?;
    let reader = io::BufReader::new(file);
    
    let mut words = HashSet::new();
    for line in reader.lines() {
        let line = line?;
        let word = line.trim();
        if word.starts_with('#') || word.is_empty() { continue; }
        if word.chars().count() <= max_len {
            words.insert(word.to_uppercase());
        }
    }
    
    Ok(words)
}

/// Load and merge lexicon, insertions, and deletions for a language.
/// Pipeline: lexicon → 1% freq filter → insertions (bypass filter) → deletions
pub fn load_filtered_words(base_dir: &str, lang: &str, max_len: usize) -> Vec<Word> {
    let lang_dir = format!("{}/words/{}", base_dir, lang);

    let valid_path    = format!("{}/lexicon.txt", lang_dir);
    let custom_path   = format!("{}/insertions.txt", lang_dir);
    let censored_path = format!("{}/deletions.txt", lang_dir);

    // 1. Load base lexicon
    let base_set = load_words(&valid_path, max_len)
        .unwrap_or_else(|_| {
            warn!("Failed to load main lexicon for {} at {}.", lang, valid_path);
            HashSet::new()
        });

    info!("Base lexicon for {} (max_len {}): {} words", lang, max_len, base_set.len());

    // 2. Apply 1% frequency filter to base lexicon only
    let base_words: Vec<Word> = base_set.into_iter()
        .map(|text| Word { signature: compute_signature(&text), len: text.len(), text })
        .collect();
    let base_words = filter_by_min_letter_frequency(base_words, 0.01);
    info!("After letter frequency filter for {} (min 1%): {} words", lang, base_words.len());

    // Re-collect filtered base into a set so we can extend with insertions
    let mut word_set: HashSet<String> = base_words.into_iter().map(|w| w.text).collect();

    // 3. Merge insertions (hand-curated — bypass frequency filter)
    if let Ok(custom) = load_words(&custom_path, max_len) {
        info!("Inserted {} words into {} lexicon.", custom.len(), lang);
        word_set.extend(custom);
    }

    // 4. Apply deletions
    if let Ok(censored) = load_words(&censored_path, max_len + 100) {
        info!("Deleted {} words from {} lexicon.", censored.len(), lang);
        for word in censored { word_set.remove(&word); }
    }

    // 5. Final sort
    let mut words: Vec<Word> = word_set.into_iter()
        .map(|text| Word { signature: compute_signature(&text), len: text.len(), text })
        .collect();
    words.sort_by(|a, b| a.text.cmp(&b.text));
    info!("Total valid words for {} after all filters: {}", lang, words.len());

    words
}

/// Remove letters (and the words containing them) that appear in fewer than `min_pct`
/// of the word list. This eliminates rare accented chars and script outliers from the bag.
pub fn filter_by_min_letter_frequency(mut words: Vec<Word>, min_pct: f64) -> Vec<Word> {
    let total = words.len();
    if total == 0 {
        return words;
    }
    let threshold = ((total as f64) * min_pct).ceil() as usize;

    // Count: for each letter, how many *distinct words* contain it
    let mut letter_word_count: HashMap<char, usize> = HashMap::new();
    for word in &words {
        let letters: HashSet<char> = word.text.chars().collect();
        for ch in letters {
            *letter_word_count.entry(ch).or_insert(0) += 1;
        }
    }

    // Valid letters are those meeting the threshold
    let valid_letters: HashSet<char> = letter_word_count
        .into_iter()
        .filter(|(_, count)| *count >= threshold)
        .map(|(ch, _)| ch)
        .collect();

    // Keep only words whose every character is a valid letter
    words.retain(|w| w.text.chars().all(|ch| valid_letters.contains(&ch)));
    words
}
