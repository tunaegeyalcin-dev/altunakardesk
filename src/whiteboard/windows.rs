use super::{
    server::{Ripple, EVENT_PROXY},
    win_linux::{altunakar_etiket_ciz, altunakar_etiket_yazi_yuzu, create_font_face, draw_text},
    Cursor, CustomEvent,
};
use hbb_common::{anyhow::anyhow, log, ResultType};
use softbuffer::{Context, Surface};
use std::{collections::HashMap, num::NonZeroU32, sync::Arc, time::Instant};
use tao::{
    dpi::{PhysicalPosition, PhysicalSize},
    event::{Event, WindowEvent},
    event_loop::{ControlFlow, EventLoopBuilder},
    platform::windows::WindowBuilderExtWindows,
    window::WindowBuilder,
};
use hbb_common::altunakar_cizim::{self as ac, SekilDeposu};
use tiny_skia::{Color, FillRule, LineCap, LineJoin, Paint, PathBuilder, PixmapMut, Stroke, Transform};

/// Altunakar: nokta dizisini yuvarlak uçlu çizgiyle boyar. Renk ARGB; tampon BGRA olduğundan
/// kırmızı ile mavi yer değiştirir (imleç çiziminde de böyle).
fn altunakar_boya(pixmap: &mut PixmapMut, noktalar: &[(f32, f32)], argb: u32, kalinlik: f32) {
    if noktalar.len() < 2 {
        return;
    }
    let mut pb = PathBuilder::new();
    pb.move_to(noktalar[0].0, noktalar[0].1);
    for p in &noktalar[1..] {
        pb.line_to(p.0, p.1);
    }
    let Some(path) = pb.finish() else {
        return;
    };
    let (r, g, b, a) = ac::argb_parcala(argb);
    let mut paint = Paint::default();
    paint.set_color_rgba8(b, g, r, a);
    paint.anti_alias = true;
    let mut stroke = Stroke::default();
    stroke.width = kalinlik;
    stroke.line_cap = LineCap::Round;
    stroke.line_join = LineJoin::Round;
    pixmap.stroke_path(&path, &paint, &stroke, Transform::identity(), None);
}

/// Altunakar: ekranların pencere içindeki dikdörtgenleri ve pencerenin başlangıcı.
fn altunakar_ekranlar() -> ((f32, f32), Vec<(f32, f32, f32, f32)>) {
    let kok = super::server::get_displays_rect()
        .map(|(x, y, _, _)| (x as f32, y as f32))
        .unwrap_or((0.0, 0.0));
    let ekranlar = crate::server::display_service::try_get_displays()
        .map(|d| {
            d.iter()
                .map(|e| {
                    (
                        e.origin().0 as f32 - kok.0,
                        e.origin().1 as f32 - kok.1,
                        e.width() as f32,
                        e.height() as f32,
                    )
                })
                .collect()
        })
        .unwrap_or_default();
    (kok, ekranlar)
}

pub(super) fn create_event_loop() -> ResultType<()> {
    let face = match create_font_face() {
        Ok(face) => Some(face),
        Err(err) => {
            log::error!("Failed to create font face: {}", err);
            None
        }
    };
    let etiket_yuzu = match altunakar_etiket_yazi_yuzu() {
        Ok(f) => Some(f),
        Err(err) => {
            log::error!("Altunakar etiket yazi yuzu yok: {}", err);
            None
        }
    };

    let event_loop = EventLoopBuilder::<(String, CustomEvent)>::with_user_event().build();
    let mut window_builder = WindowBuilder::new()
        .with_title("RustDesk whiteboard")
        .with_transparent(true)
        .with_always_on_top(true)
        .with_skip_taskbar(true)
        .with_decorations(false);

    let mut final_size = None;
    if let Ok((x, y, w, h)) = super::server::get_displays_rect() {
        if w > 0 && h > 0 {
            final_size = Some(PhysicalSize::new(w, h));
            window_builder = window_builder
                .with_position(PhysicalPosition::new(x, y))
                .with_inner_size(PhysicalSize::new(1, 1));
        } else {
            window_builder =
                window_builder.with_fullscreen(Some(tao::window::Fullscreen::Borderless(None)));
        }
    } else {
        window_builder =
            window_builder.with_fullscreen(Some(tao::window::Fullscreen::Borderless(None)));
    }

    let window = Arc::new(window_builder.build::<(String, CustomEvent)>(&event_loop)?);
    window.set_ignore_cursor_events(true)?;

    let context = Context::new(window.clone()).map_err(|e| {
        log::error!("Failed to create context: {}", e);
        anyhow!(e.to_string())
    })?;
    let mut surface = Surface::new(&context, window.clone()).map_err(|e| {
        log::error!("Failed to create surface: {}", e);
        anyhow!(e.to_string())
    })?;

    let proxy = event_loop.create_proxy();
    EVENT_PROXY.write().unwrap().replace(proxy);
    let _call_on_ret = crate::common::SimpleCallOnReturn {
        b: true,
        f: Box::new(move || {
            let _ = EVENT_PROXY.write().unwrap().take();
        }),
    };

    let mut ripples: Vec<Ripple> = Vec::new();
    let mut last_cursors: HashMap<String, Cursor> = HashMap::new();
    let mut resized = final_size.is_none();
    // Altunakar: beyaz tahta şekilleri ve bağlıyken ekran çerçevesi (anahtar → etiket).
    let mut sekiller = SekilDeposu::default();
    let mut cerceveler: HashMap<String, String> = HashMap::new();
    let (kok, ekranlar) = altunakar_ekranlar();
    // Altunakar: yalnız bir şey değişince (ya da tıklama halkası canlanırken) yeniden çiz.
    // Önceden döngü durmadan çiziyordu; çerçeve her oturumda açık olduğundan işlemciyi yorardı.
    let mut kirli = true;

    event_loop.run(move |event, _, control_flow| {
        *control_flow = if ripples.is_empty() {
            ControlFlow::Wait
        } else {
            ControlFlow::WaitUntil(Instant::now() + std::time::Duration::from_millis(16))
        };

        match event {
            Event::WindowEvent { event, .. } => match event {
                WindowEvent::CloseRequested => {
                    *control_flow = ControlFlow::Exit;
                }
                _ => {}
            },
            Event::RedrawRequested(_) => {
                if !resized {
                    if let Some(size) = final_size.take() {
                        window.set_inner_size(size);
                    }
                    resized = true;
                    kirli = true;
                    return;
                }

                let (width, height) = {
                    let size = window.inner_size();
                    (size.width, size.height)
                };

                let (Some(width), Some(height)) = (NonZeroU32::new(width), NonZeroU32::new(height))
                else {
                    return;
                };
                if let Err(e) = surface.resize(width, height) {
                    log::error!("Failed to resize surface: {}", e);
                    return;
                }

                let mut buffer = match surface.buffer_mut() {
                    Ok(buf) => buf,
                    Err(e) => {
                        log::error!("Failed to get buffer: {}", e);
                        return;
                    }
                };
                let Some(mut pixmap) = PixmapMut::from_bytes(
                    bytemuck::cast_slice_mut(&mut buffer),
                    width.get(),
                    height.get(),
                ) else {
                    log::error!("Failed to create pixmap from buffer");
                    return;
                };
                pixmap.fill(Color::TRANSPARENT);

                for c in sekiller.hepsi() {
                    for cizgi in ac::sekil_cizgileri(c, kok) {
                        altunakar_boya(&mut pixmap, &cizgi, c.argb, c.kalinlik);
                    }
                }
                if let Some(etiket) = cerceveler.values().next() {
                    let ekran_listesi = if ekranlar.is_empty() {
                        vec![(0.0, 0.0, width.get() as f32, height.get() as f32)]
                    } else {
                        ekranlar.clone()
                    };
                    for cizgi in ac::cerceve_cizgileri(&ekran_listesi, ac::CERCEVE_KALINLIK) {
                        altunakar_boya(&mut pixmap, &cizgi, ac::CERCEVE_ARGB, ac::CERCEVE_KALINLIK);
                    }
                    if let Some(face) = etiket_yuzu.as_ref().or(face.as_ref()) {
                        // Mac'teki etiketle aynı: 15 nokta yazı, ekran ölçeğine göre piksel.
                        let olcek = window.scale_factor() as f32;
                        let boyut = 15.0 * olcek;
                        let (r, g, b, a) = ac::argb_parcala(ac::CERCEVE_ARGB);
                        let mut kutu = Paint::default();
                        kutu.set_color_rgba8(b, g, r, a);
                        kutu.anti_alias = true;
                        for e in &ekran_listesi {
                            let ust = e.1 + ac::CERCEVE_KALINLIK + 6.0 * olcek;
                            altunakar_etiket_ciz(
                                &mut pixmap,
                                face,
                                etiket,
                                e.0 + e.2 / 2.0,
                                ust,
                                boyut,
                                &kutu,
                            );
                        }
                    }
                }

                Ripple::retain_active(&mut ripples);
                for ripple in &ripples {
                    let (radius, alpha) = ripple.get_radius_alpha();

                    let mut ripple_paint = Paint::default();
                    // Note: The real color is bgra here.
                    ripple_paint.set_color_rgba8(64, 64, 255, (alpha * 128.0) as u8);
                    ripple_paint.anti_alias = true;

                    let mut ripple_pb = PathBuilder::new();
                    ripple_pb.push_circle(ripple.x, ripple.y, radius);
                    if let Some(path) = ripple_pb.finish() {
                        pixmap.fill_path(
                            &path,
                            &ripple_paint,
                            FillRule::Winding,
                            Transform::identity(),
                            None,
                        );
                    }
                }

                for cursor in last_cursors.values() {
                    let (x, y) = (cursor.x, cursor.y);
                    let size = 1.5f32;

                    let mut pb = PathBuilder::new();
                    pb.move_to(x, y);
                    pb.line_to(x, y + 16.0 * size);
                    pb.line_to(x + 4.0 * size, y + 13.0 * size);
                    pb.line_to(x + 7.0 * size, y + 20.0 * size);
                    pb.line_to(x + 9.0 * size, y + 19.0 * size);
                    pb.line_to(x + 6.0 * size, y + 12.0 * size);
                    pb.line_to(x + 11.0 * size, y + 12.0 * size);
                    pb.close();

                    if let Some(path) = pb.finish() {
                        let rgba = super::argb_to_rgba(cursor.argb);
                        let mut arrow_paint = Paint::default();
                        // Note: The real color is bgra here.
                        arrow_paint.set_color_rgba8(rgba.2, rgba.1, rgba.0, rgba.3);
                        arrow_paint.anti_alias = true;
                        pixmap.fill_path(
                            &path,
                            &arrow_paint,
                            FillRule::Winding,
                            Transform::identity(),
                            None,
                        );

                        let mut black_paint = Paint::default();
                        black_paint.set_color_rgba8(0, 0, 0, 255);
                        black_paint.anti_alias = true;
                        let mut stroke = Stroke::default();
                        stroke.width = 1.0f32;
                        pixmap.stroke_path(
                            &path,
                            &black_paint,
                            &stroke,
                            Transform::identity(),
                            None,
                        );

                        face.as_ref().map(|face| {
                            draw_text(
                                &mut pixmap,
                                face,
                                &cursor.text,
                                x + 24.0 * size,
                                y + 24.0 * size,
                                &arrow_paint,
                                14.0f32,
                            );
                        });
                    }
                }

                if let Err(e) = buffer.present() {
                    log::error!("Failed to present surface: {}", e);
                    return;
                }
            }
            Event::MainEventsCleared => {
                if kirli || !ripples.is_empty() {
                    kirli = false;
                    window.request_redraw();
                }
            }
            Event::UserEvent((k, evt)) => {
                kirli = true;
                match evt {
                    CustomEvent::Cursor(cursor) => {
                        if cursor.btns != 0 {
                            ripples.push(Ripple {
                                x: cursor.x,
                                y: cursor.y,
                                start_time: Instant::now(),
                            });
                        }
                        last_cursors.insert(k, cursor);
                    }
                    CustomEvent::Cizim(c) => {
                        sekiller.uygula(&k, c);
                    }
                    CustomEvent::Cerceve(c) => {
                        cerceveler.insert(k, c.etiket);
                    }
                    CustomEvent::Clear => {
                        sekiller.temizle(&k);
                        cerceveler.remove(&k);
                        last_cursors.remove(&k);
                    }
                    CustomEvent::Exit => {
                        *control_flow = ControlFlow::Exit;
                    }
                }
            }
            _ => (),
        }
    });
}
