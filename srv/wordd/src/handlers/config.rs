use actix_web::{get, web, HttpResponse, Responder};
use crate::models::{AppState, LangInfo, ConfigResponse};
use std::collections::HashMap;
use log::info;

#[get("/langs")]
pub async fn get_langs(data: web::Data<AppState>) -> impl Responder {
    let langs: Vec<LangInfo> = data.supported_langs.iter().map(|code| {
        let name = match code.as_str() {
            "en" => "English",
            "es" => "Español",
            "fr" => "Français",
            "de" => "Deutsch",
            _ => code.as_str(),
        }.to_string();
        LangInfo { name, code: code.clone() }
    }).collect();

    HttpResponse::Ok().json(langs)
}

#[get("/config/{lang}")]
pub async fn get_config(
    data: web::Data<AppState>,
    path: web::Path<String>,
) -> impl Responder {
    let lang = path.into_inner().to_lowercase();
    
    // Retrieve pre-computed values from AppState
    let bag = match data.tile_bags.get(&lang) {
        Some(b) => b.clone(),
        None => return HttpResponse::BadRequest().finish(),
    };

    let vowels = match data.vowel_sets.get(&lang) {
        Some(v) => v.clone(),
        None => return HttpResponse::BadRequest().finish(),
    };

    let unicorns = match data.unicorn_sets.get(&lang) {
        Some(u) => {
            // Convert unicorn letters to HashMap with standard value of 10
            u.iter().map(|&c| (c, 10)).collect::<HashMap<char, usize>>()
        },
        None => return HttpResponse::BadRequest().finish(),
    };

    let word_count = data.word_lists.get(&lang).map(|w| w.len()).unwrap_or(0);
    let tiles = bag.clone();

    info!("Generated {} config with {} tiles, {} unicorns, {} vowels, and {} words", 
          lang, tiles.values().sum::<usize>(), unicorns.len(), vowels.len(), word_count);

    HttpResponse::Ok().json(ConfigResponse {
        tiles,
        unicorns,
        vowels,
        bag,
        word_count,
    })
}
