use hbb_common::{bail, ResultType};
use tiny_skia::{FillRule, Paint, PathBuilder, PixmapMut, Point, Rect, Transform};
use ttf_parser::Face;
// A helper struct to bridge `ttf-parser` and `tiny-skia`.
struct PathBuilderWrapper<'a> {
    path_builder: &'a mut PathBuilder,
    transform: Transform,
}

impl ttf_parser::OutlineBuilder for PathBuilderWrapper<'_> {
    fn move_to(&mut self, x: f32, y: f32) {
        let mut pt = Point::from_xy(x, y);
        self.transform.map_point(&mut pt);
        self.path_builder.move_to(pt.x, pt.y);
    }

    fn line_to(&mut self, x: f32, y: f32) {
        let mut pt = Point::from_xy(x, y);
        self.transform.map_point(&mut pt);
        self.path_builder.line_to(pt.x, pt.y);
    }

    fn quad_to(&mut self, x1: f32, y1: f32, x: f32, y: f32) {
        let mut pt1 = Point::from_xy(x1, y1);
        self.transform.map_point(&mut pt1);
        let mut pt = Point::from_xy(x, y);
        self.transform.map_point(&mut pt);
        self.path_builder.quad_to(pt1.x, pt1.y, pt.x, pt.y);
    }

    fn curve_to(&mut self, x1: f32, y1: f32, x2: f32, y2: f32, x: f32, y: f32) {
        let mut pt1 = Point::from_xy(x1, y1);
        self.transform.map_point(&mut pt1);
        let mut pt2 = Point::from_xy(x2, y2);
        self.transform.map_point(&mut pt2);
        let mut pt = Point::from_xy(x, y);
        self.transform.map_point(&mut pt);
        self.path_builder
            .cubic_to(pt1.x, pt1.y, pt2.x, pt2.y, pt.x, pt.y);
    }

    fn close(&mut self) {
        self.path_builder.close();
    }
}

// Draws a string of text with the white background rectangle onto the pixmap.
pub(super) fn draw_text(
    pixmap: &mut PixmapMut,
    face: &Face,
    text: &str,
    x: f32,
    y: f32,
    paint: &Paint,
    font_size: f32,
) {
    let units_per_em = face.units_per_em() as f32;
    let scale = font_size / units_per_em;

    // --- 1. Calculate text dimensions for the background ---
    let mut total_width = 0.0;
    for ch in text.chars() {
        let glyph_id = face.glyph_index(ch).unwrap_or_default();
        if let Some(h_advance) = face.glyph_hor_advance(glyph_id) {
            total_width += h_advance as f32 * scale;
        }
    }

    // Use font metrics for a consistent background height.
    let font_height = (face.ascender() - face.descender()) as f32 * scale;
    let ascent = face.ascender() as f32 * scale;
    // Add some padding around the text
    let padding = 3.0;

    let mut bg_filled = false;
    // --- 2. Draw the white background rectangle ---
    if let Some(bg_rect) = Rect::from_xywh(
        x - padding,
        y - ascent - padding,
        total_width + 2.0 * padding,
        font_height + 2.0 * padding,
    ) {
        // Corner radius
        let radius = 5.0;
        let path = {
            let mut pb = PathBuilder::new();
            let r_x = bg_rect.x();
            let r_y = bg_rect.y();
            let r_w = bg_rect.width();
            let r_h = bg_rect.height();
            pb.move_to(r_x + radius, r_y);
            pb.line_to(r_x + r_w - radius, r_y);
            pb.quad_to(r_x + r_w, r_y, r_x + r_w, r_y + radius);
            pb.line_to(r_x + r_w, r_y + r_h - radius);
            pb.quad_to(r_x + r_w, r_y + r_h, r_x + r_w - radius, r_y + r_h);
            pb.line_to(r_x + radius, r_y + r_h);
            pb.quad_to(r_x, r_y + r_h, r_x, r_y + r_h - radius);
            pb.line_to(r_x, r_y + radius);
            pb.quad_to(r_x, r_y, r_x + radius, r_y);
            pb.close();
            pb.finish()
        };

        if let Some(path) = path {
            let mut bg_paint = Paint::default();
            bg_paint.set_color_rgba8(255, 255, 255, 255);
            bg_paint.anti_alias = true;
            pixmap.fill_path(
                &path,
                &bg_paint,
                FillRule::Winding,
                Transform::identity(),
                None,
            );
            bg_filled = true;
        }
    }

    // --- 3. Draw the text ---
    let transform = Transform::from_translate(x, y).pre_scale(scale, -scale);
    let mut path_builder = PathBuilder::new();
    let mut current_x = 0.0;

    for ch in text.chars() {
        let glyph_id = face.glyph_index(ch).unwrap_or_default();

        let mut builder = PathBuilderWrapper {
            path_builder: &mut path_builder,
            transform: transform.post_translate(current_x, 0.0),
        };

        face.outline_glyph(glyph_id, &mut builder);

        if let Some(h_advance) = face.glyph_hor_advance(glyph_id) {
            current_x += h_advance as f32 * scale;
        }
    }

    if let Some(path) = path_builder.finish() {
        if bg_filled {
            let mut text_paint = Paint::default();
            text_paint.set_color_rgba8(0, 0, 0, 255);
            text_paint.anti_alias = true;
            pixmap.fill_path(
                &path,
                &text_paint,
                FillRule::Winding,
                Transform::identity(),
                None,
            );
        } else {
            pixmap.fill_path(&path, paint, FillRule::Winding, Transform::identity(), None);
        }
    }
}

pub(super) fn create_font_face() -> ResultType<Face<'static>> {
    let mut font_db = fontdb::Database::new();
    font_db.load_system_fonts();
    let query = fontdb::Query {
        families: &[fontdb::Family::Monospace, fontdb::Family::SansSerif],
        ..fontdb::Query::default()
    };
    let Some(font_id) = font_db.query(&query) else {
        bail!("No monospace or sans-serif font found!");
    };
    let Some((font_source, face_index)) = font_db.face_source(font_id) else {
        bail!("No face found for font!");
    };
    // Load the font data into a static slice to satisfy `ttf-parser`'s lifetime requirements.
    // We use `Box::leak` to leak the memory, which is acceptable here since the font data
    // is needed for the entire lifetime of the application.
    let font_data: &'static [u8] = Box::leak(match font_source {
        fontdb::Source::File(path) => std::fs::read(path)?.into_boxed_slice(),
        fontdb::Source::Binary(data) => data.as_ref().as_ref().to_vec().into_boxed_slice(),
        fontdb::Source::SharedFile(path, _) => std::fs::read(path)?.into_boxed_slice(),
    });
    let face = Face::parse(font_data, face_index)?;
    Ok(face)
}

/// Altunakar: ekran çerçevesi etiketinin yazı yüzü (Windows'ta Segoe UI, yoksa sans-serif).
/// İmleç adlarındaki daktilo yazısı (`create_font_face`) etikette özensiz duruyordu.
pub(super) fn altunakar_etiket_yazi_yuzu() -> ResultType<Face<'static>> {
    let mut font_db = fontdb::Database::new();
    font_db.load_system_fonts();
    let query = fontdb::Query {
        families: &[fontdb::Family::Name("Segoe UI"), fontdb::Family::SansSerif],
        weight: fontdb::Weight::SEMIBOLD,
        ..fontdb::Query::default()
    };
    let Some(font_id) = font_db.query(&query) else {
        bail!("No sans-serif font found!");
    };
    let Some((font_source, face_index)) = font_db.face_source(font_id) else {
        bail!("No face found for font!");
    };
    let font_data: &'static [u8] = Box::leak(match font_source {
        fontdb::Source::File(path) => std::fs::read(path)?.into_boxed_slice(),
        fontdb::Source::Binary(data) => data.as_ref().as_ref().to_vec().into_boxed_slice(),
        fontdb::Source::SharedFile(path, _) => std::fs::read(path)?.into_boxed_slice(),
    });
    Ok(Face::parse(font_data, face_index)?)
}

/// Altunakar: ekran çerçevesinin etiketi; Mac'teki gibi `kutu` renginde yuvarlak kutuda
/// beyaz yazı. Kutunun üst kenarı `ust_y`, ortası `merkez_x`.
pub(super) fn altunakar_etiket_ciz(
    pixmap: &mut PixmapMut,
    face: &Face,
    text: &str,
    merkez_x: f32,
    ust_y: f32,
    font_size: f32,
    kutu: &Paint,
) {
    let scale = font_size / face.units_per_em() as f32;
    let genislik: f32 = text
        .chars()
        .filter_map(|ch| face.glyph_hor_advance(face.glyph_index(ch).unwrap_or_default()))
        .map(|a| a as f32 * scale)
        .sum();
    let ascent = face.ascender() as f32 * scale;
    let yukseklik = (face.ascender() - face.descender()) as f32 * scale;
    let (bosluk_x, bosluk_y) = (font_size * 0.7, font_size * 0.35);
    let x = merkez_x - genislik / 2.0;

    if let Some(r) = Rect::from_xywh(
        x - bosluk_x,
        ust_y,
        genislik + 2.0 * bosluk_x,
        yukseklik + 2.0 * bosluk_y,
    ) {
        let yaricap = (r.height() / 2.0).min(font_size * 0.6);
        let mut pb = PathBuilder::new();
        pb.move_to(r.x() + yaricap, r.y());
        pb.line_to(r.right() - yaricap, r.y());
        pb.quad_to(r.right(), r.y(), r.right(), r.y() + yaricap);
        pb.line_to(r.right(), r.bottom() - yaricap);
        pb.quad_to(r.right(), r.bottom(), r.right() - yaricap, r.bottom());
        pb.line_to(r.x() + yaricap, r.bottom());
        pb.quad_to(r.x(), r.bottom(), r.x(), r.bottom() - yaricap);
        pb.line_to(r.x(), r.y() + yaricap);
        pb.quad_to(r.x(), r.y(), r.x() + yaricap, r.y());
        pb.close();
        if let Some(path) = pb.finish() {
            pixmap.fill_path(&path, kutu, FillRule::Winding, Transform::identity(), None);
        }
    }

    let transform =
        Transform::from_translate(x, ust_y + bosluk_y + ascent).pre_scale(scale, -scale);
    let mut path_builder = PathBuilder::new();
    let mut current_x = 0.0;
    for ch in text.chars() {
        let glyph_id = face.glyph_index(ch).unwrap_or_default();
        let mut builder = PathBuilderWrapper {
            path_builder: &mut path_builder,
            transform: transform.post_translate(current_x, 0.0),
        };
        face.outline_glyph(glyph_id, &mut builder);
        if let Some(h_advance) = face.glyph_hor_advance(glyph_id) {
            current_x += h_advance as f32 * scale;
        }
    }
    if let Some(path) = path_builder.finish() {
        let mut beyaz = Paint::default();
        beyaz.set_color_rgba8(255, 255, 255, 255);
        beyaz.anti_alias = true;
        pixmap.fill_path(&path, &beyaz, FillRule::Winding, Transform::identity(), None);
    }
}
