use actix_web::{get, web, HttpResponse, Responder};
use crate::models::{AppState, RandQuery};
use crate::utils::{select_random_from_bag, select_random_from_list};

#[get("/rand/langs/{lang}/letter")]
pub async fn rand_letter(
    data: web::Data<AppState>,
    path: web::Path<String>,
    query: web::Query<RandQuery>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    let count = query.count.unwrap_or(1);
    
    let bag = match data.tile_bags.get(&lang) {
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
    
    let constraints = crate::services::generator::WordConstraints {
        letters: query.letters.as_deref(),
        min_vowels: query.min_vowels,
        min_consonants: query.min_consonants,
        vowels,
    };
    
    let selected = crate::services::generator::select_random_words_with_constraints(words, count, constraints);

    let output = selected.join("\n");
    HttpResponse::Ok().content_type("text/plain").body(output)
}
