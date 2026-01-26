use std::collections::HashSet;
use rand::seq::SliceRandom;
use crate::utils::{contains_only_letters, count_vowels_consonants};
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
    words: &HashSet<String>,
    constraints: &WordConstraints
) -> Vec<String> {
    // Optimization: Pre-calculate max length if we have a letters constraint
    // (A word cannot be longer than the available tiles, including wildcards)
    let max_len = constraints.letters.map(|l| l.len()).unwrap_or(usize::MAX);

    words.iter()
        .filter(|word| {
            // 1. Length constraint (cheap)
            if word.len() > max_len {
                return false;
            }

            // 2. Letters constraint (includes wildcard logic)
            if let Some(available_letters) = constraints.letters {
                if !contains_only_letters(word, available_letters) {
                    return false;
                }
            }
            
            // 3. Rack structural constraints (vowels/consonants)
            if constraints.min_vowels.is_some() || constraints.min_consonants.is_some() {
                let (vowel_count, consonant_count) = count_vowels_consonants(word, constraints.vowels);
                
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
        .cloned()
        .collect()
}

/// Select random words from the dictionary, respecting constraints
/// If constraints are present, performs a linear scan to find any matches
pub fn select_random_words_with_constraints(
    words: &HashSet<String>,
    count: usize,
    constraints: WordConstraints
) -> Vec<String> {
    
    // Fast path: No constraints
    if constraints.letters.is_none() && constraints.min_vowels.is_none() && constraints.min_consonants.is_none() {
        let mut rng = rand::thread_rng();
        let words_vec: Vec<&String> = words.iter().collect();
        return (0..count).map(|_| {
             words_vec.choose(&mut rng).map(|s| (*s).clone()).unwrap_or_else(|| "WORD".to_string())
        }).collect();
    }

    // Slow path: Linear scan for constraints
    // This is O(N) where N is dictionary size.
    // For 200k words, this takes ~10-50ms depending on constraints.
    // This is preferred over rejection sampling (random guessing) which can fail repeatedly for strict constraints.
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
