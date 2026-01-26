use actix_web::{get, web, HttpResponse, Responder};
use crate::models::AppState;
use log::info;

fn check_word_logic(
    data: &web::Data<AppState>,
    lang: &str,
    word: &str
) -> HttpResponse {
    let words = match data.word_lists.get(&lang.to_lowercase()) {
        Some(w) => w,
        None => return HttpResponse::BadRequest().body(format!("Language '{}' not supported", lang)),
    };

    let word_upper = word.to_uppercase();
    let is_valid = words.binary_search_by(|w| w.text.cmp(&word_upper)).is_ok();

    if !is_valid {
        info!("Invalid word queried ({}): {}", lang, word_upper);
        return HttpResponse::NotFound().finish();
    }

    info!("Valid word queried ({}): {}", lang, word_upper);
    HttpResponse::Ok().body(format!("Valid word: {}", word_upper))
}

fn validate_word_logic(
    data: &web::Data<AppState>,
    lang: &str,
    word: &str
) -> HttpResponse {
    let words = match data.word_lists.get(&lang.to_lowercase()) {
        Some(w) => w,
        None => return HttpResponse::BadRequest().finish(),
    };

    let word_upper = word.to_uppercase();
    if words.binary_search_by(|w| w.text.cmp(&word_upper)).is_ok() {
        HttpResponse::Ok().finish()
    } else {
        HttpResponse::NotFound().finish()
    }
}

#[get("/word/{lang}/{word}")]
pub async fn check_word_lang(
    data: web::Data<AppState>,
    path: web::Path<(String, String)>,
) -> impl Responder {
    let (lang, word) = path.into_inner();
    check_word_logic(&data, &lang, &word)
}

// Backward compatibility (default to 'en')
#[get("/word/{word}")]
pub async fn check_word(
    data: web::Data<AppState>,
    word: web::Path<String>,
) -> impl Responder {
    check_word_logic(&data, "en", &word.into_inner())
}

#[get("/validate/{lang}/{word}")]
pub async fn validate_word_lang(
    data: web::Data<AppState>,
    path: web::Path<(String, String)>,
) -> impl Responder {
    let (lang, word) = path.into_inner();
    validate_word_logic(&data, &lang, &word)
}

#[get("/validate/{word}")]
pub async fn validate_word(
    data: web::Data<AppState>,
    word: web::Path<String>,
) -> impl Responder {
    validate_word_logic(&data, "en", &word.into_inner())
}
