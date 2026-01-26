use std::collections::{HashMap, HashSet};
use serde::{Deserialize, Serialize};

/// Application state shared across all handlers
pub struct AppState {
    pub word_lists: HashMap<String, HashSet<String>>,
    pub supported_langs: Vec<String>,
    pub letter_bags: HashMap<String, HashMap<char, usize>>,
    pub vowel_sets: HashMap<String, Vec<char>>,
    pub consonant_sets: HashMap<String, Vec<char>>,
    pub unicorn_sets: HashMap<String, Vec<char>>,
}

#[derive(Serialize)]
pub struct LangInfo {
    pub name: String,
    pub code: String,
}

#[derive(Serialize)]
pub struct ConfigResponse {
    pub tiles: HashMap<char, usize>,
    pub unicorns: HashMap<char, usize>,
    pub vowels: Vec<char>,
    pub bag: HashMap<char, usize>,
}

#[derive(Deserialize)]
pub struct RandQuery {
    pub count: Option<usize>,
    pub letters: Option<String>,
    pub min_vowels: Option<usize>,
    pub min_consonants: Option<usize>,
}
