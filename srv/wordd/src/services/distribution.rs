use std::collections::HashMap;

use crate::models::Word;

/// Calculate letter frequency distribution from a set of words.
/// The lexicon defines the alphabet — accented chars are included at natural frequency.
pub fn calculate_distribution_from_set(words: &[Word]) -> HashMap<char, usize> {
    let mut freq = HashMap::new();
    for word in words {
        for ch in word.text.chars() {
            if ch.is_alphabetic() {
                *freq.entry(ch.to_uppercase().next().unwrap()).or_insert(0) += 1;
            }
        }
    }
    freq
}

pub fn compute_tile_bag(freq: &HashMap<char, usize>, total_tiles: usize) -> HashMap<char, usize> {
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
        let mut sorted_tiles: Vec<_> = freq.keys().cloned().collect();
        sorted_tiles.sort_by_key(|&c| std::cmp::Reverse(freq[&c]));
        for i in 0..(remaining_tiles as usize) {
            if let Some(&c) = sorted_tiles.get(i % sorted_tiles.len()) {
                *tiles.entry(c).or_insert(0) += 1;
            }
        }
    } else if remaining_tiles < 0 {
        // Remove overshoots from rarest letters (but keep at least 1)
        let mut sorted_tiles: Vec<_> = freq.keys().cloned().collect();
        sorted_tiles.sort_by_key(|&c| freq[&c]);
        let mut to_remove = (-remaining_tiles) as usize;
        let mut i = 0;
        while to_remove > 0 {
            if let Some(&c) = sorted_tiles.get(i % sorted_tiles.len()) {
                let count = tiles.get_mut(&c).unwrap();
                if *count > 1 {
                    *count -= 1;
                    to_remove -= 1;
                }
            }
            i += 1;
            if i > 1000 { break; } // Safety break
        }
    }

    tiles
}
