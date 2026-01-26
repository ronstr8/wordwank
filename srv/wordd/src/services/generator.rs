use crate::models::Word;
use crate::utils::{contains_only_letters, count_vowels_consonants, compute_signature};
use rand::seq::SliceRandom;
use log::debug;

pub struct WordConstraints<'a> {
    pub letters: Option<&'a str>,
    pub min_vowels: Option<usize>,
    pub min_consonants: Option<usize>,
    pub vowels: &'a [char],
}

/// Find words in the dictionary that match the given constraints
/// Returns a list of all matching words
pub fn find_matching_words(
    words: &[Word],
    constraints: &WordConstraints
) -> Vec<String> {
    // Optimization: Pre-calculate max length if we have a letters constraint
    let max_len = constraints.letters.map(|l| l.len()).unwrap_or(usize::MAX);
    
    // Optimization: Compute rack signature for fast filtering
    let rack_sig = constraints.letters.map(compute_signature).unwrap_or(0);

    words.iter()
        .filter(|word| {
            // 1. Length constraint (cheap)
            if word.len > max_len {
                return false;
            }

            // 2. Bitmask Filter (Super cheap)
            // If word has bits set that rack doesn't have, it's impossible match.
            // Note: This assumes rack_sig represents available tiles. 
            
            let has_wildcard = constraints.letters.map(|l| l.contains('_')).unwrap_or(false);
            if !has_wildcard && constraints.letters.is_some() && (word.signature & !rack_sig) != 0 {
                 return false;
            }

            // 3. Letters constraint (full check)
            if let Some(available_letters) = constraints.letters {
                if !contains_only_letters(&word.text, available_letters) {
                    return false;
                }
            }
            
            // 4. Rack structural constraints (vowels/consonants)
            if constraints.min_vowels.is_some() || constraints.min_consonants.is_some() {
                let (vowel_count, consonant_count) = count_vowels_consonants(&word.text, constraints.vowels);
                
                if let Some(min_v) = constraints.min_vowels {
                    if vowel_count < min_v {
                        return false;
                    }
                }
                
                if let Some(min_c) = constraints.min_consonants {
                    if consonant_count < min_c {
                        return false;
                    }
                }
            }
            
            true
        })
        .map(|w| w.text.clone())
        .collect()
}

/// Select random words from the dictionary, respecting constraints
pub fn select_random_words_with_constraints(
    words: &[Word],
    count: usize,
    constraints: WordConstraints
) -> Vec<String> {
    
    // Fast path: No constraints
    if constraints.letters.is_none() && constraints.min_vowels.is_none() && constraints.min_consonants.is_none() {
        let mut rng = rand::thread_rng();
        return (0..count).map(|_| {
             words.choose(&mut rng).map(|w| w.text.clone()).unwrap_or_else(|| "WORD".to_string())
        }).collect();
    }

    let candidates = find_matching_words(words, &constraints);
    
    if candidates.is_empty() {
        debug!("No words found matching constraints");
        return Vec::new();
    }

    let mut rng = rand::thread_rng();
    let mut selected = Vec::new();
    
    for _ in 0..count {
        if let Some(word) = candidates.choose(&mut rng) {
            selected.push(word.clone());
        }
    }
    
    selected
}
