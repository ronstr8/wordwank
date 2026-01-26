use std::collections::HashSet;
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
        if !word.is_empty() && word.len() <= max_len {
            words.insert(word.to_uppercase());
        }
    }
    
    Ok(words)
}

/// Load and merge lexicon, insertions, and deletions for a language
pub fn load_filtered_words(base_dir: &str, lang: &str, max_len: usize) -> Vec<Word> {
    let lang_dir = format!("{}/words/{}", base_dir, lang);
    
    let valid_path = format!("{}/lexicon.txt", lang_dir);
    let custom_path = format!("{}/insertions.txt", lang_dir);
    let censored_path = format!("{}/deletions.txt", lang_dir);

    let mut word_set = load_words(&valid_path, max_len)
        .unwrap_or_else(|_| {
            warn!("Failed to load main lexicon for {} at {}.", lang, valid_path);
            HashSet::new()
        });

    if let Ok(custom) = load_words(&custom_path, max_len) {
        info!("Inserted {} words into {} lexicon.", custom.len(), lang);
        word_set.extend(custom);
    }

    if let Ok(censored) = load_words(&censored_path, max_len + 100) { // deletions don't need length filter
        info!("Deleted {} words from {} lexicon.", censored.len(), lang);
        for word in censored {
            word_set.remove(&word);
        }
    }

    info!("Total valid words for {} (max_len {}): {}", lang, max_len, word_set.len());

    // Convert to Vec<Word> with signatures
    let mut words: Vec<Word> = word_set.into_iter()
        .map(|text| Word {
            signature: compute_signature(&text),
            len: text.len(),
            text,
        })
        .collect();
    
    // Sort for deterministic order and potential binary search
    words.sort_by(|a, b| a.text.cmp(&b.text));
    
    words
}
