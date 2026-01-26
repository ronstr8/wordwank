use std::collections::HashMap;
use std::collections::HashSet;

/// Calculate letter frequency from a set of words
pub fn calculate_distribution_from_set(words: &HashSet<String>) -> HashMap<char, usize> {
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

/// Compute tile bag from letter frequencies
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
