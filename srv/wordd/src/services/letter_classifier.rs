use std::collections::{HashMap, HashSet};

/// Classify letters into vowels, consonants, and unicorns (rarest)
pub fn classify_letters(
    freq: &HashMap<char, usize>,
    lang: &str
) -> (Vec<char>, Vec<char>, Vec<char>) {
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
