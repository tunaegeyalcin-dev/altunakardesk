use serde_derive::{Deserialize, Serialize};

mod client;
mod server;

#[cfg(target_os = "windows")]
mod windows;
#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "macos")]
mod macos;
#[cfg(any(target_os = "windows", target_os = "linux"))]
mod win_linux;

#[cfg(target_os = "windows")]
use windows::create_event_loop;
#[cfg(target_os = "macos")]
use macos::create_event_loop;
#[cfg(target_os = "linux")]
pub use linux::is_supported;

pub use client::*;
pub use server::*;

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(tag = "t", content = "c")]
pub enum CustomEvent {
    Cursor(Cursor),
    Clear,
    Exit,
    // Altunakar: beyaz tahta şekli ve bağlıyken ekran çerçevesi (hbb_common::altunakar_cizim).
    Cizim(hbb_common::altunakar_cizim::Cizim),
    Cerceve(hbb_common::altunakar_cizim::Cerceve),
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(tag = "t")]
pub struct Cursor {
    pub x: f32,
    pub y: f32,
    pub argb: u32,
    pub btns: i32,
    pub text: String,
}
