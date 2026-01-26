use std::collections::{HashMap, HashSet};
use rand::seq::SliceRandom;

/// Check if a word can be formed using only the available letters
/// Supports '_' as a wildcard that can match any letter
pub fn contains_only_letters(word: &str, letters: &str) -> bool {
    let word_upper = word.to_uppercase();
    let mut letter_counts: HashMap<char, usize> = HashMap::new();
    let mut wildcards = 0;
    
    for ch in letters.to_uppercase().chars() {
        if ch.is_alphabetic() {
            *letter_counts.entry(ch).or_insert(0) += 1;
        } else if ch == '_' {
            wildcards += 1;
        }
    }
    
    let mut word_letters: HashMap<char, usize> = HashMap::new();
    for ch in word_upper.chars() {
        if ch.is_alphabetic() {
            *word_letters.entry(ch).or_insert(0) += 1;
        }
    }
    
    for (ch, &needed) in word_letters.iter() {
        let available = letter_counts.get(ch).copied().unwrap_or(0);
        if needed > available {
            let deficit = needed - available;
            if wildcards >= deficit {
                wildcards -= deficit;
            } else {
                return false;
            }
        }
    }
    
    true
}

/// Count vowels and consonants in a word
pub fn count_vowels_consonants(word: &str, vowels: &[char]) -> (usize, usize) {
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

/// Select random items from a weighted bag (HashMap)
pub fn select_random_from_bag(bag: &HashMap<char, usize>, count: usize) -> Vec<char> {
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

/// Select random items from a list
pub fn select_random_from_list(list: &[char], count: usize) -> Vec<char> {
    let mut rng = rand::thread_rng();
    (0..count).map(|_| {
        list.choose(&mut rng).copied().unwrap_or('A')
    }).collect()
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
