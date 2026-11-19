/* io/q_io_filetext.c — the q `0:` File Text surface: Save Text, Prepare Text,
 * Load CSV, Load Fixed, Key-Value Pairs, plus the `-14!` CSV-quote alias.
 * Oracle: ref/file-text.md (CLEAN ROOM).  Split out of io/q_io.c (2026-07-31),
 * which keeps the byte core this file stands on (io/q_io.h) — the
 * base-plus-specialization shape net/q_wire + q_wirefile already use.
 * Binary file formats (`1:`/`2:`) are not implemented here yet.
 *
 * Ownership: helper inputs are BORROWED, helper outputs are OWNED by the
 * caller; on any partial failure a helper releases everything it allocated
 * before returning the error.
 *
 * RAY_FN_RESTRICTED note: nothing here touches the filesystem directly — the
 * byte core owns both the access and the restricted-mode gate. */
#define _POSIX_C_SOURCE 200809L
#include "qlang/q_count.h"
#include "qlang/q_registry_internal.h" /* q_str_split_lines, q_list_collapse */
#include "qlang/base/q_err.h"
#include "qlang/io/q_io.h"  /* the byte core: paths, the slice read, the write */
#include "qlang/ops/q_dollar.h" /* q_cast_designator, q_dollar_tok — Tok column parses */
#include "qlang/parse/q_tok.h"  /* q_tok — header names take the cells' blank trim */
#include "qlang/base/q_calendar.h" /* civil->days for the csv fast path's DATE spans */
#include "core/numparse.h"        /* ray_parse_i64/f64 — the csv fast path's numeric spans */
#include "qlang/q_builtins.h" /* q_string_fn — Prepare Text cell text; q_io_filetext_csv_quote decl */
#include "lang/eval.h"      /* ray_at_fn */
#include "table/sym.h"      /* ray_sym_str */
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* ---- Save Text: `:path 0: strings -------------------------------------- */
static ray_t* ft_save_text(ray_t* fsym, ray_t* y) {
    ray_t* path = q_io_path_operand(fsym);
    if (!path) return q_err(QE_TYPE);
    if (!y || !(y->type == RAY_LIST || y->type == RAY_STR)) {
        ray_release(path);
        return q_err(QE_TYPE);
    }
    int64_t n = q_count(y);
    size_t total = 0;
    for (int64_t i = 0; i < n; i++) {
        ray_t* ia = ray_i64(i);
        ray_t* e = ray_at_fn(y, ia);
        ray_release(ia);
        if (!e || RAY_IS_ERR(e)) { ray_release(path); return e ? e : q_err(QE_OOM); }
        if (e->type != -RAY_STR) {
            ray_release(e); ray_release(path);
            return q_err(QE_TYPE);
        }
        total += ray_str_len(e) + 1;                       /* line + '\n' */
        ray_release(e);
    }
    char* buf = (char*)malloc(total ? total : 1);
    if (!buf) { ray_release(path); return q_err(QE_OOM); }
    size_t w = 0;
    for (int64_t i = 0; i < n; i++) {
        ray_t* ia = ray_i64(i);
        ray_t* e = ray_at_fn(y, ia);
        ray_release(ia);
        if (!e || RAY_IS_ERR(e)) { free(buf); ray_release(path); return e ? e : q_err(QE_OOM); }
        size_t l = ray_str_len(e);
        memcpy(buf + w, ray_str_ptr(e), l);
        w += l;
        buf[w++] = '\n';
        ray_release(e);
    }
    ray_t* bad = q_io_write_all(path, buf, w);   /* owns the missing-directories law */
    free(buf);
    ray_release(path);
    if (bad) return bad;
    ray_retain(fsym);
    return fsym;
}

/* ---- Prepare Text: delim 0: table | list-of-columns --------------------- */

/* One cell -> OWNED RAY_STR raw text (no quoting).  Borrows atom. */
static ray_t* ft_cell_text(ray_t* atom) {
    ray_t* s0 = q_string_fn(atom);              /* charv post-1b */
    if (!s0 || RAY_IS_ERR(s0)) return s0;
    ray_t* s = q_str_in(s0);                    /* legacy STR for the writers */
    ray_release(s0);
    if (!s || RAY_IS_ERR(s)) return s;
    if (atom->type == -RAY_DATE && s->type == -RAY_STR) {
        /* Prepare Text renders temporals ISO 8601 (doc: 2022-03-14) — the
         * date dots become dashes; other temporals already match. */
        size_t n = ray_str_len(s);
        char* b = (char*)malloc(n ? n : 1);
        if (b) {
            const char* p = ray_str_ptr(s);
            for (size_t i = 0; i < n; i++) b[i] = p[i] == '.' ? '-' : p[i];
            ray_t* d = ray_str(b, n);
            free(b);
            ray_release(s);
            return d;
        }
    }
    if (atom->type == -RAY_MONTH && s->type == -RAY_STR && ray_str_len(s)) {
        /* `string` drops the m (#898) but the csv contract writes it: bare 2026.08 would read back as a float. */
        size_t n = ray_str_len(s);
        char b[32];
        if (n + 1 <= sizeof b) {
            memcpy(b, ray_str_ptr(s), n);
            b[n] = 'm';
            ray_release(s);
            return ray_str(b, n + 1);
        }
    }
    return s;
}

/* Quote rule (doc): a cell containing the delimiter or a line break is
 * embraced with '"' and every embedded '"' doubled; otherwise raw.  Appends
 * the (possibly embraced) cell to *buf/(w..cap).  Returns 0 on OOM. */
static int ft_quote_append(char** buf, size_t* w, size_t* cap,
                             const char* c, size_t n, char delim) {
    int embrace = 0;
    size_t extra = 2;
    for (size_t i = 0; i < n; i++) {
        if (c[i] == delim || c[i] == '\n') embrace = 1;
        if (c[i] == '"') extra++;
    }
    size_t need = *w + n + (embrace ? extra : 0) + 2;
    if (need > *cap) {
        size_t nc = *cap ? *cap : 64;
        while (nc < need) nc *= 2;
        char* nb = (char*)realloc(*buf, nc);
        if (!nb) return 0;
        *buf = nb; *cap = nc;
    }
    char* b = *buf;
    if (!embrace) {
        memcpy(b + *w, c, n);
        *w += n;
        return 1;
    }
    b[(*w)++] = '"';
    for (size_t i = 0; i < n; i++) {
        if (c[i] == '"') b[(*w)++] = '"';
        b[(*w)++] = c[i];
    }
    b[(*w)++] = '"';
    return 1;
}

/* `-14!x` quote escape (basics/internal.md: prepare data for CSV export) — ONE
 * cell through the Save-Text quote rule above, delimiter fixed at ','. */
ray_t* q_io_filetext_csv_quote(ray_t* x) {
    const char* p;
    int64_t n;
    if (!q_str_text_bytes(x, &p, &n)) return q_err(QE_TYPE);
    char* buf = NULL;
    size_t w = 0, cap = 0;
    if (!ft_quote_append(&buf, &w, &cap, p, (size_t)n, ',')) {
        free(buf);
        return q_err(QE_WSFULL);
    }
    ray_t* r = ray_charv(buf ? buf : "", (int64_t)w);
    free(buf);
    return r;
}

static ray_t* ft_prepare(char delim, ray_t* y) {
    /* columns + optional names */
    int64_t nc = 0;
    ray_t* namev = NULL;                 /* borrowed via table introspection */
    ray_t** litems = NULL;
    int is_table = y && y->type == RAY_TABLE;
    if (is_table) nc = ray_table_ncols(y);
    else if (y && y->type == RAY_LIST) { nc = q_count(y); litems = (ray_t**)ray_data(y); }
    else return q_err(QE_TYPE);
    (void)namev;
    if (nc == 0) return ray_list_new(1);
    /* validate columns; find the shared row count */
    int64_t L = -1;
    for (int64_t c = 0; c < nc; c++) {
        ray_t* col = is_table ? ray_table_get_col_idx(y, c) : litems[c];  /* borrowed */
        int64_t l;
        if (col && col->type == -RAY_STR) l = (int64_t)ray_str_len(col);  /* char column */
        else if (col && (ray_is_vec(col) || col->type == RAY_LIST)) {
            l = q_count(col);
            if (col->type == RAY_LIST) {                  /* must be all strings */
                ray_t** it = (ray_t**)ray_data(col);
                for (int64_t i = 0; i < l; i++)
                    if (!it[i] || (it[i]->type != -RAY_STR && it[i]->type != RAY_CHARV))
                        return q_err(QE_TYPE);
            }
        } else return q_err(QE_TYPE);
        if (L < 0) L = l;
        else if (l != L) return q_err(QE_LENGTH);
    }
    ray_t* out = ray_list_new(L + 1 > 0 ? L + 1 : 1);
    if (RAY_IS_ERR(out)) return out;
    char* buf = NULL;
    size_t cap = 0;
    /* header row: table column names */
    if (is_table) {
        size_t w = 0;
        for (int64_t c = 0; c < nc; c++) {
            if (c) {
                if (w + 1 > cap) { cap = cap ? cap * 2 : 64; buf = (char*)realloc(buf, cap); if (!buf) { ray_release(out); return q_err(QE_OOM); } }
                buf[w++] = delim;
            }
            int64_t nm = ray_table_col_name(y, c);
            ray_t* ns = ray_sym_str(nm);                   /* borrowed */
            if (!ns || !ft_quote_append(&buf, &w, &cap, ray_str_ptr(ns), ray_str_len(ns), delim)) {
                free(buf); ray_release(out);
                return q_err(QE_OOM);
            }
        }
        ray_t* line = ray_str(buf ? buf : "", w);
        out = ray_list_append(out, line);
        ray_release(line);
        if (RAY_IS_ERR(out)) { free(buf); return out; }
    }
    for (int64_t i = 0; i < L; i++) {
        size_t w = 0;
        for (int64_t c = 0; c < nc; c++) {
            if (c) {
                if (w + 1 > cap) { cap = cap ? cap * 2 : 64; buf = (char*)realloc(buf, cap); if (!buf) { ray_release(out); return q_err(QE_OOM); } }
                buf[w++] = delim;
            }
            ray_t* col = is_table ? ray_table_get_col_idx(y, c) : litems[c];  /* borrowed */
            int ok;
            if (col->type == -RAY_STR) {                   /* char column: one char */
                char ch = ray_str_ptr(col)[i];
                ok = ft_quote_append(&buf, &w, &cap, &ch, 1, delim);
            } else if (col->type == RAY_CHARV) {           /* char column (charv) */
                char ch = ((const char*)ray_data(col))[i];
                ok = ft_quote_append(&buf, &w, &cap, &ch, 1, delim);
            } else if (col->type == RAY_LIST) {            /* string column */
                ray_t** it = (ray_t**)ray_data(col);
                const char* cp; int64_t cn;
                if (!q_str_text_bytes(it[i], &cp, &cn)) { cp = ""; cn = 0; }
                ok = ft_quote_append(&buf, &w, &cap, cp, (size_t)cn, delim);
            } else {
                ray_t* ia = ray_i64(i);
                ray_t* atom = ray_at_fn(col, ia);
                ray_release(ia);
                if (!atom || RAY_IS_ERR(atom)) { free(buf); ray_release(out); return atom ? atom : q_err(QE_OOM); }
                ray_t* cs = ft_cell_text(atom);
                ray_release(atom);
                if (!cs || RAY_IS_ERR(cs)) { free(buf); ray_release(out); return cs ? cs : q_err(QE_OOM); }
                if (cs->type != -RAY_STR) { ray_release(cs); free(buf); ray_release(out); return q_err(QE_TYPE); }
                ok = ft_quote_append(&buf, &w, &cap, ray_str_ptr(cs), ray_str_len(cs), delim);
                ray_release(cs);
            }
            if (!ok) { free(buf); ray_release(out); return q_err(QE_OOM); }
        }
        ray_t* line = ray_str(buf ? buf : "", w);
        out = ray_list_append(out, line);
        ray_release(line);
        if (RAY_IS_ERR(out)) { free(buf); return out; }
    }
    free(buf);
    return out;
}

/* ---- Load CSV / Load Fixed shared plumbing ------------------------------ */

/* Type char -> Tok tag via THE cast home (q_cast_designator; upper case =
 * Tok).  '*' keeps the field a string, ' ' skips the column, unknown -> 0.
 * Read case-insensitively: the doc spells the codes upper case, the tracked
 * kdb programs (qdocs/misc/aoc/2022/day04.q, 2020/day02.q) spell them lower. */
static int8_t ft_tag(char c, int* is_str, int* is_skip) {
    *is_str = 0; *is_skip = 0;
    if (c == ' ') { *is_skip = 1; return 0; }
    if (c == '*') { *is_str = 1; return 0; }
    c = (char)toupper((unsigned char)c);
    if (c < 'A' || c > 'Z') return 0;
    ray_t* d = ray_str(&c, 1);
    if (!d || RAY_IS_ERR(d)) return 0;
    int is_tok = 0;
    int8_t tag = q_cast_designator(d, &is_tok, NULL);
    ray_release(d);
    return is_tok ? tag : 0;
}

/* A file slice as its rows.  The byte core streams just the slice, so the
 * chunk form costs O(chunk) per call and not O(file). */
static ray_t* ft_lines_of(ray_t* path, int64_t off, int64_t want) {
    ray_t* b = q_io_read_slice(path, off, want, NULL);
    if (!b || RAY_IS_ERR(b)) return b;
    int64_t n = q_count(b);
    ray_t* rows = q_str_split_lines(n ? (const char*)ray_data(b) : "", (size_t)n);
    ray_release(b);
    return rows;
}

/* Normalize the RIGHT operand of Load CSV / Load Fixed into an OWNED
 * RAY_LIST of row strings.  *single = 1 for the one-string-no-newline form
 * (kdb returns a list of parsed ATOMS for it, not columns). */
static ray_t* ft_rows(ray_t* y, int* single) {
    *single = 0;
    if (!y) return q_err(QE_TYPE);
    if (y->type == -RAY_STR) {
        const char* p = ray_str_ptr(y);
        size_t n = ray_str_len(y);
        if (memchr(p, '\n', n)) return q_str_split_lines(p, n);
        *single = 1;
        ray_t* out = ray_list_new(1);
        if (RAY_IS_ERR(out)) return out;
        out = ray_list_append(out, y);                     /* retains y */
        return out;
    }
    if (y->type == -RAY_SYM) {
        ray_t* path = q_io_path_operand(y);
        if (!path) return q_err(QE_TYPE);
        ray_t* rows = ft_lines_of(path, 0, -1);
        ray_release(path);
        return rows;
    }
    if (y->type == RAY_LIST || y->type == RAY_STR) {
        int64_t n = q_count(y);
        ray_t** e = y->type == RAY_LIST ? (ray_t**)ray_data(y) : NULL;
        /* (filesymbol; offset[; length]) chunk form — the read verbs' triple,
         * clamped rather than 'domain (q_io.h). */
        if (e && n >= 2 && n <= 3 && e[0] && e[0]->type == -RAY_SYM) {
            ray_t* path;
            int64_t off, want;
            ray_t* bad = q_io_file_triple(e[0], e[1], n == 3 ? e[2] : NULL, 1, &path, &off, &want);
            if (bad) return bad;
            ray_t* rows = ft_lines_of(path, off, want);
            ray_release(path);
            return rows;
        }
        /* list / str-vector of row strings */
        ray_t* out = ray_list_new(n > 0 ? n : 1);
        if (RAY_IS_ERR(out)) return out;
        for (int64_t i = 0; i < n; i++) {
            ray_t* ia = ray_i64(i);
            ray_t* it = ray_at_fn(y, ia);
            ray_release(ia);
            if (!it || RAY_IS_ERR(it)) { ray_release(out); return it ? it : q_err(QE_OOM); }
            if (it->type != -RAY_STR) {
                ray_release(it); ray_release(out);
                return q_err(QE_TYPE);
            }
            out = ray_list_append(out, it);
            ray_release(it);
            if (RAY_IS_ERR(out)) return out;
        }
        return out;
    }
    return q_err(QE_TYPE);
}

/* flag=1 (embedded line returns): merge physical rows whose quotes are
 * unbalanced with the following row, restoring the '\n'.  Owns+returns. */
static ray_t* ft_merge_quoted(ray_t* rows) {
    int64_t n = q_count(rows);
    ray_t* out = ray_list_new(n > 0 ? n : 1);
    if (RAY_IS_ERR(out)) { ray_release(rows); return out; }
    ray_t** e = (ray_t**)ray_data(rows);
    char* acc = NULL;                        /* pending logical row */
    size_t used = 0;                         /* bytes of acc in use */
    size_t quotes = 0;                       /* running '"' parity  */
    for (int64_t i = 0; i < n; i++) {
        const char* p = ray_str_ptr(e[i]);
        size_t l = ray_str_len(e[i]);
        char* na = (char*)realloc(acc, used + l + 2);
        if (!na) { free(acc); ray_release(out); ray_release(rows); return q_err(QE_OOM); }
        acc = na;
        if (used) acc[used++] = '\n';        /* rejoin BEFORE the copy — the '\n'
                                              * must not land on memcpy's target */
        memcpy(acc + used, p, l);
        used += l;
        for (size_t k = 0; k < l; k++) if (p[k] == '"') quotes++;
        if ((quotes & 1) == 0) {
            ray_t* s = ray_str(acc, used);
            out = ray_list_append(out, s);
            ray_release(s);
            free(acc); acc = NULL; used = 0; quotes = 0;
            if (RAY_IS_ERR(out)) { ray_release(rows); return out; }
        }
    }
    if (acc) {                               /* unterminated tail row */
        ray_t* s = ray_str(acc, used);
        out = ray_list_append(out, s);
        ray_release(s);
        free(acc);
        if (RAY_IS_ERR(out)) { ray_release(rows); return out; }
    }
    ray_release(rows);
    return out;
}

/* Split one row into fields on a delimiter; '"'-opened fields are
 * quote-scanned ('""' -> literal '"').  Appends OWNED strings to `fields`. */
static ray_t* ft_fields(ray_t* fields, const char* r, size_t n, char delim) {
    size_t i = 0;
    for (;;) {
        char* fb = (char*)malloc(n + 1);
        if (!fb) { ray_release(fields); return q_err(QE_OOM); }
        size_t fl = 0;
        if (i < n && r[i] == '"') {
            /* each " toggles quoting; "" while quoted is one ", text after a close is kept (TorQ filterformat.csv:6) */
            int quoted = 0;
            while (i < n && (quoted || r[i] != delim)) {
                if (r[i] != '"') fb[fl++] = r[i++];
                else if (quoted && i + 1 < n && r[i + 1] == '"') { fb[fl++] = '"'; i += 2; }
                else { quoted = !quoted; i++; }
            }
        } else {
            while (i < n && r[i] != delim) fb[fl++] = r[i++];
        }
        ray_t* f = ray_str(fb, fl);
        free(fb);
        fields = ray_list_append(fields, f);
        ray_release(f);
        if (RAY_IS_ERR(fields)) return fields;
        if (i >= n) break;
        i++;                                                /* past delim */
        if (i == n) {                                       /* trailing delim */
            ray_t* z = ray_str("", 0);
            fields = ray_list_append(fields, z);
            ray_release(z);
            break;
        }
    }
    return fields;
}

/* Parse one field per its column recipe.  OWNED atom/string. */
static ray_t* ft_parse_field(ray_t* field, int8_t tag, int is_str) {
    if (is_str) { ray_retain(field); return field; }
    return q_dollar_tok(tag, field);
}

/* Collapse a column accumulator: '*' columns cross out as lists of char
 * vectors HERE — a table column never meets the wrap's boundary walk; typed
 * columns Tok-parse (q_dollar_tok distributes over lists) then collapse. */
static ray_t* ft_finish_col(ray_t* colacc, int8_t tag, int is_str) {
    if (is_str) { ray_retain(colacc); return q_str_charv_out(colacc); }
    ray_t* parsed = q_dollar_tok(tag, colacc);
    if (!parsed || RAY_IS_ERR(parsed)) return parsed;
    ray_t* v = q_list_collapse(parsed);                     /* owned */
    ray_release(parsed);
    return v;
}

/* ---- the direct-parse fast path ---------------------------------------------
 * The generic rows path boxes every field THREE times (field STR, column-
 * accumulator STR, Tok atom) before the collapse — ~5 heap objects a field.
 * When every kept column's tag parses a (ptr,len) span straight into its vec
 * payload — the SAME scanners q_tok runs — the loader writes the element
 * where it stands: no field objects, no accumulator.  A '*' column (is_str)
 * or an unsupported tag sends the load back down the generic path. */

static int ft_span_admits(int8_t tag) {
    switch (tag) {
    case RAY_BOOL: case RAY_BYTE_ONLY: case RAY_I16: case RAY_I32: case RAY_I64:
    case RAY_F32: case RAY_F64: case RAY_CHARV: case RAY_SYM: case RAY_GUID:
    case RAY_DATE: case RAY_MONTH: case RAY_TIME: case RAY_MINUTE: case RAY_SECOND:
    case RAY_TIMESPAN: case RAY_TIMESTAMP: case RAY_DATETIME:
        return 1;
    default: return 0;
    }
}

/* Hot lane: a field span of pure digits of len<=3 resolves without the full
 * ft_span_tok dispatch (same value law — anything else returns 0 -> caller
 * falls back to ft_span_tok). */
static inline int ft_span_fast(int8_t tag, const char* p, size_t len, uint8_t* d) {
    if (len == 1) {
        char c = p[0];
        if (tag == RAY_CHARV) { *d = (uint8_t)c; return 1; }
        if (c < '0' || c > '9') return 0;
        switch (tag) {
        case RAY_I64: *(int64_t*)d = c - '0'; return 1;
        case RAY_I32: *(int32_t*)d = c - '0'; return 1;
        case RAY_I16: *(int16_t*)d = (int16_t)(c - '0'); return 1;
        case RAY_BOOL: *d = (uint8_t)(c == '1'); return 1;
        case RAY_BYTE_ONLY: *d = (uint8_t)(c - '0'); return 1;   /* hex digit = value */
        case RAY_MINUTE: *(int32_t*)d = (c - '0') * 60; return 1;
        case RAY_F64: { double r = c - '0'; memcpy(d, &r, 8); return 1; }
        case RAY_F32: { float r = c - '0'; memcpy(d, &r, 4); return 1; }
        default: return 0;
        }
    }
    if (len > 3 || len == 0) return 0;
    int64_t v = 0;
    for (size_t i = 0; i < len; i++) {
        char c = p[i];
        if (c < '0' || c > '9') return 0;
        v = v * 10 + (c - '0');
    }
    switch (tag) {
    case RAY_I64: *(int64_t*)d = v; return 1;
    case RAY_I32: *(int32_t*)d = (int32_t)v; return 1;
    case RAY_I16: *(int16_t*)d = (int16_t)v; return 1;
    case RAY_MINUTE: *(int32_t*)d = (int32_t)(v * 60); return 1;
    case RAY_F64: { double r = (double)v; memcpy(d, &r, 8); return 1; }
    case RAY_F32: { float r = (float)v; memcpy(d, &r, 4); return 1; }
    default: return 0;
    }
}

/* One field span -> typed payload at `d`, identical value law to q_tok (same
 * scanners, same trims, unparseable/out-of-domain -> the typed null's bytes). */
static void ft_span_tok(int8_t tag, const char* p, size_t len, uint8_t* d) {
    while (len && *p == ' ') { p++; len--; }
    while (len && p[len - 1] == ' ') len--;
    switch (tag) {
    case RAY_BOOL: { uint8_t b = len == 1 && strchr("1TtXxYy", p[0]) != NULL; *d = b; return; }
    case RAY_BYTE_ONLY: {
        uint64_t v = 0;
        size_t i = 0;
        for (; i < len; i++) {
            char c = p[i];
            int dg = (c >= '0' && c <= '9') ? c - '0'
                   : (c >= 'a' && c <= 'f') ? c - 'a' + 10
                   : (c >= 'A' && c <= 'F') ? c - 'A' + 10 : -1;
            if (dg < 0) break;
            v = (v << 4) | (uint64_t)dg;
            if (v > 0xff) break;
        }
        *d = (len == 0 || i != len || v > 0xff) ? 0 : (uint8_t)v;
        return;
    }
    case RAY_I64: {
        int64_t v = 0;
        size_t u = len ? ray_parse_i64(p, len, &v) : 0;
        *(int64_t*)d = (!len || u != len || v == INT64_MIN) ? NULL_I64 : v;
        return;
    }
    case RAY_I32: {
        uint32_t ip;
        if (q_tok_ipv4(p, len, &ip)) { *(int32_t*)d = (int32_t)ip; return; }
        int64_t v = 0;
        size_t u = len ? ray_parse_i64(p, len, &v) : 0;
        *(int32_t*)d = (!len || u != len || v > INT32_MAX || v < -INT32_MAX) ? NULL_I32 : (int32_t)v;
        return;
    }
    case RAY_I16: {
        int64_t v = 0;
        size_t u = len ? ray_parse_i64(p, len, &v) : 0;
        *(int16_t*)d = (!len || u != len || v > INT16_MAX || v < -INT16_MAX) ? NULL_I16 : (int16_t)v;
        return;
    }
    case RAY_F64: case RAY_F32: {
        double v = 0;
        size_t u = len ? ray_parse_f64(p, len, &v) : 0;
        int bad = !len || u != len;
        if (tag == RAY_F64) { double r = bad ? NULL_F64 : v; memcpy(d, &r, 8); }
        else { float r = bad ? NULL_F32 : (float)v; memcpy(d, &r, 4); }
        return;
    }
    case RAY_CHARV: { *d = len ? (uint8_t)p[0] : 0x20; return; }
    case RAY_SYM: { *(int64_t*)d = ray_sym_intern(len ? p : "", len); return; }
    case RAY_GUID: {
        uint8_t bytes[16];
        if (!q_tok_uuid(p, len, bytes) && !tok_ip_guid(p, len, bytes)) memset(bytes, 0, 16);
        memcpy(d, bytes, 16);
        return;
    }
    case RAY_DATE: {
        int64_t y, mo, dy;
        *(int32_t*)d = q_tok_date(p, len, &y, &mo, &dy) && q_calendar_date_valid(y, mo, dy)
                     ? (int32_t)q_calendar_days_from_civil(y, mo, dy) : NULL_I32;
        return;
    }
    case RAY_MONTH: {
        int64_t mo;
        *(int32_t*)d = q_tok_month(p, len, &mo) ? (int32_t)mo : NULL_I32;
        return;
    }
    case RAY_TIME: {
        int32_t ms;
        *(int32_t*)d = q_tok_time(p, len, &ms) ? ms : NULL_I32;
        return;
    }
    case RAY_MINUTE: {
        int64_t secs, frac;
        *(int32_t*)d = len && len <= 2 && p[0] >= '0' && p[0] <= '9' &&
                       (len == 1 || (p[1] >= '0' && p[1] <= '9'))
                       ? (int32_t)((len == 1 ? p[0] - '0' : (p[0] - '0') * 10 + p[1] - '0') * 60)
                       : q_tok_clock(p, len, &secs, &frac) && secs / 60 <= INT32_MAX
                         ? (int32_t)(secs / 60) : NULL_I32;
        return;
    }
    case RAY_SECOND: {
        int64_t secs, frac;
        *(int32_t*)d = q_tok_clock(p, len, &secs, &frac) && secs <= INT32_MAX
                     ? (int32_t)secs : NULL_I32;
        return;
    }
    case RAY_TIMESPAN: {
        int64_t ns;
        *(int64_t*)d = q_tok_timespan_ns(p, len, &ns) ? ns : NULL_I64;
        return;
    }
    case RAY_TIMESTAMP: case RAY_DATETIME: {
        int64_t ns;
        if (len && p[len - 1] == 'D') {
            int64_t y, mo, dy;
            if (q_tok_date(p, len - 1, &y, &mo, &dy)) len--;   /* the bare-D strip (tok_ts_bare_d) */
        }
        if (!q_tok_ts(p, len, &ns)) {
            if (tag == RAY_TIMESTAMP) *(int64_t*)d = NULL_I64;
            else { double r = NULL_F64; memcpy(d, &r, 8); }
            return;
        }
        if (tag == RAY_TIMESTAMP) *(int64_t*)d = ns;
        else { double r = (double)ns / 86400000000000.0; memcpy(d, &r, 8); }
        return;
    }
    default: memset(d, 0, 8); return;
    }
}

/* Rows -> column vecs, writing each field's payload in place (the fast path).
 * Rows arrive WITHOUT materializing a LIST of STR atoms: a RAY_STR vector's
 * `ray_str_vec_get`, a LIST's STR items, or the '\n' lines of one text buffer
 * (q_str_split_lines' law: '\r' stripped, the segment after a terminal '\n'
 * dropped).  `tags`/`fskip`/`nt` as ft_load_csv computes them.  Returns the
 * OWNED list of `nout` column vecs, or an error. */
#define FT_ROWS_STRVEC 1
#define FT_ROWS_LIST   2
#define FT_ROWS_TEXT   3
static ray_t* ft_load_fast(ray_t* y, ray_t** items, const char* text, size_t tlen, int mode,
                           int64_t nrows, int64_t first, char delim,
                           const int8_t* tags, const int* fskip, size_t nt,
                           int64_t nout, int64_t ndata) {
    ray_t* cols = ray_list_new(nout > 0 ? nout : 1);
    if (!cols || RAY_IS_ERR(cols)) return cols ? cols : q_err(QE_OOM);
    ray_t** cv = (ray_t**)ray_data(cols);
    int64_t c = 0;
    for (size_t j = 0; j < nt; j++) {
        if (fskip[j]) continue;
        ray_t* v = ray_vec_new(tags[j], ndata > 0 ? ndata : 1);
        if (!v || RAY_IS_ERR(v)) { ray_release(cols); return v ? v : q_err(QE_OOM); }
        v->len = ndata;
        cols = ray_list_append(cols, v);
        ray_release(v);
        if (RAY_IS_ERR(cols)) return cols;
        cv = (ray_t**)ray_data(cols);           /* append may have moved the slots */
        c++;
    }
    char* scratch = NULL;
    size_t scap = 0;
    if (mode == FT_ROWS_TEXT) {
        /* single fused pass: fields delimited by delim-or-'\n', writes go
         * through per-column cursors — no per-row string materialization or
         * second line scan. */
        size_t tpos = 0;
        for (int64_t i = 0; i < first && tpos < tlen; i++) {
            while (tpos < tlen && text[tpos] != '\n') tpos++;
            if (tpos < tlen) tpos++;
        }
        int8_t* wtag = (int8_t*)malloc((size_t)(nout ? nout : 1) * sizeof(int8_t));
        size_t* wesz = (size_t*)malloc((size_t)(nout ? nout : 1) * sizeof(size_t));
        uint8_t** wdst = (uint8_t**)malloc((size_t)(nout ? nout : 1) * sizeof(uint8_t*));
        if (!wtag || !wesz || !wdst) {
            free(wtag); free(wesz); free(wdst); ray_release(cols); return q_err(QE_OOM);
        }
        {
            int64_t ci = 0;
            for (size_t j = 0; j < nt; j++) {
                if (fskip[j]) continue;
                wtag[ci] = tags[j];
                wesz[ci] = ray_type_sizes[(uint8_t)tags[j]];
                wdst[ci] = (uint8_t*)ray_data(cv[ci]);
                ci++;
            }
        }
        int64_t rows_done = 0;
        while (tpos < tlen && rows_done < ndata) {
            size_t j = 0;
            int64_t ci = 0;
            while (tpos < tlen) {
                if (text[tpos] == '\n') { tpos++; break; }
                const char* sp;
                size_t sl;
                int nl_end = 0;
                int stored = 0;
                /* fused digit lane: scan and value in one pass for the int family */
                if (j < nt && !fskip[j] && wtag[ci] >= RAY_I16 && wtag[ci] <= RAY_I64 &&
                    text[tpos] >= '0' && text[tpos] <= '9') {
                    int maxd = wtag[ci] == RAY_I64 ? 18 : wtag[ci] == RAY_I32 ? 9 : 4;
                    size_t e = tpos;
                    int64_t v = 0;
                    int nd = 0, clean = 1;
                    while (e < tlen) {
                        char c = text[e];
                        if (c >= '0' && c <= '9') { if (nd < 19) { v = v * 10 + (c - '0'); nd++; } else clean = 0; e++; }
                        else break;
                    }
                    if (clean && nd && nd <= maxd &&
                        (e == tlen || text[e] == delim || text[e] == '\n')) {
                        if (wtag[ci] == RAY_I64) *(int64_t*)wdst[ci] = v;
                        else if (wtag[ci] == RAY_I32) *(int32_t*)wdst[ci] = (int32_t)v;
                        else *(int16_t*)wdst[ci] = (int16_t)v;
                        wdst[ci] += wesz[ci]; ci++;
                        stored = 1;
                        nl_end = e < tlen && text[e] == '\n';
                        tpos = e;
                    }
                }
                if (!stored && text[tpos] == '"') {
                    /* ft_fields' quoted arm, unescaped into scratch */
                    size_t e = tpos, w = 0;
                    int quoted = 0;
                    while (e < tlen && text[e] != '\n' && (quoted || text[e] != delim)) {
                        if (text[e] != '"') {
                            if (w >= scap) {
                                size_t nc = scap ? scap * 2 : 256;
                                char* nb = (char*)realloc(scratch, nc);
                                if (!nb) { free(scratch); free(wtag); free(wesz); free(wdst); ray_release(cols); return q_err(QE_OOM); }
                                scratch = nb; scap = nc;
                            }
                            scratch[w++] = text[e++];
                        } else if (quoted && e + 1 < tlen && text[e + 1] == '"') {
                            if (w >= scap) {
                                size_t nc = scap ? scap * 2 : 256;
                                char* nb = (char*)realloc(scratch, nc);
                                if (!nb) { free(scratch); free(wtag); free(wesz); free(wdst); ray_release(cols); return q_err(QE_OOM); }
                                scratch = nb; scap = nc;
                            }
                            scratch[w++] = '"'; e += 2;
                        } else { quoted = !quoted; e++; }
                    }
                    sp = scratch ? scratch : "";
                    sl = w;
                    tpos = e;
                    nl_end = e < tlen && text[e] == '\n';
                } else if (!stored) {
                    size_t e = tpos;
                    while (e < tlen && text[e] != delim && text[e] != '\n') e++;
                    nl_end = e < tlen && text[e] == '\n';
                    sp = text + tpos;
                    sl = e - tpos;
                    if (nl_end && sl && text[tpos + sl - 1] == '\r') sl--;
                    tpos = e;
                }
                if (j < nt && !stored) {
                    if (!fskip[j]) {
                        if (!ft_span_fast(wtag[ci], sp, sl, wdst[ci]))
                            ft_span_tok(wtag[ci], sp, sl, wdst[ci]);
                        wdst[ci] += wesz[ci]; ci++;
                    }
                }
                j++;
                if (tpos < tlen) {
                    if (nl_end || text[tpos] == '\n') { tpos++; break; }
                    if (text[tpos] == delim) { tpos++; continue; }
                }
                break;
            }
            /* short row: the untouched columns take the empty-field null */
            while (j < nt) {
                if (!fskip[j]) { ft_span_tok(wtag[ci], "", 0, wdst[ci]); wdst[ci] += wesz[ci]; ci++; }
                j++;
            }
            rows_done++;
        }
        free(scratch); free(wtag); free(wesz); free(wdst);
        return cols;
    }
    for (int64_t i = first; i < nrows; i++) {
        size_t rn = 0;
        const char* rr;
        if (mode == FT_ROWS_LIST) {
            rr = ray_str_ptr(items[i]);
            rn = ray_str_len(items[i]);
        } else {
            rr = ray_str_vec_get(y, i, &rn);
            if (!rr) { rr = ""; rn = 0; }
        }
        size_t fi = 0;
        int64_t ri = i - first;
        int64_t ci = 0;
        for (size_t j = 0; j < nt; j++) {
            const char* sp = "";
            size_t sl = 0;
            if (fi < rn) {
                if (rr[fi] == '"') {
                    /* ft_fields' quoted arm, unescaped into scratch */
                    size_t e = fi, w = 0;
                    int quoted = 0;
                    while (e < rn && (quoted || rr[e] != delim)) {
                        if (rr[e] != '"') {
                            if (w >= scap) {
                                size_t nc = scap ? scap * 2 : 256;
                                char* nb = (char*)realloc(scratch, nc);
                                if (!nb) { free(scratch); ray_release(cols); return q_err(QE_OOM); }
                                scratch = nb; scap = nc;
                            }
                            scratch[w++] = rr[e++];
                        } else if (quoted && e + 1 < rn && rr[e + 1] == '"') {
                            if (w >= scap) {
                                size_t nc = scap ? scap * 2 : 256;
                                char* nb = (char*)realloc(scratch, nc);
                                if (!nb) { free(scratch); ray_release(cols); return q_err(QE_OOM); }
                                scratch = nb; scap = nc;
                            }
                            scratch[w++] = '"'; e += 2;
                        } else { quoted = !quoted; e++; }
                    }
                    sp = scratch ? scratch : "";
                    sl = w;
                    fi = e;
                } else {
                    size_t e = fi;
                    while (e < rn && rr[e] != delim) e++;
                    sp = rr + fi;
                    sl = e - fi;
                    fi = e;
                }
            }
            if (!fskip[j]) {
                size_t esz = ray_type_sizes[(uint8_t)tags[j]];
                uint8_t* d = (uint8_t*)ray_data(cv[ci]) + (size_t)ri * esz;
                if (!ft_span_fast(tags[j], sp, sl, d)) ft_span_tok(tags[j], sp, sl, d);
                ci++;
            }
            if (fi < rn) fi++;                    /* past delim; fi==rn leaves later fields "" */
        }
    }
    free(scratch);
    return cols;
}

static ray_t* ft_load_csv(ray_t* types, ray_t* delimspec, ray_t* flag, ray_t* y) {
    const char* ts = ray_str_ptr(types);
    size_t nt = ray_str_len(types);
    if (nt == 0) return q_err(QE_TYPE);
    /* delimiter: char atom (len-1 string) or enlisted -> header row */
    char delim;
    int header = 0;
    if (delimspec && delimspec->type == -RAY_STR && ray_str_len(delimspec) == 1)
        delim = ray_str_ptr(delimspec)[0];
    else if (delimspec &&
             (delimspec->type == RAY_LIST || delimspec->type == RAY_STR) &&
             q_count(delimspec) == 1) {
        /* enlisted delimiter -> first row is column names.  `enlist ","` is
         * an engine STR VECTOR (10h), a boxed 1-list also accepted. */
        ray_t* ia = ray_i64(0);
        ray_t* d0 = ray_at_fn(delimspec, ia);
        ray_release(ia);
        if (!d0 || RAY_IS_ERR(d0)) return d0 ? d0 : q_err(QE_OOM);
        if (d0->type != -RAY_STR || ray_str_len(d0) != 1) {
            ray_release(d0);
            return q_err(QE_TYPE);
        }
        delim = ray_str_ptr(d0)[0];
        ray_release(d0);
        header = 1;
    } else return q_err(QE_TYPE);
    int embed_nl = 0;
    if (flag) {
        int64_t fv;
        ray_t* ferr = q_type_i64_or_err(flag, &fv, "0:: flag");
        if (ferr) return ferr;
        embed_nl = fv != 0;
    }
    /* column recipes */
    int8_t* tags = (int8_t*)malloc(nt);
    int* fstr = (int*)malloc(nt * sizeof(int));
    int* fskip = (int*)malloc(nt * sizeof(int));
    if (!tags || !fstr || !fskip) { free(tags); free(fstr); free(fskip); return q_err(QE_OOM); }
    for (size_t j = 0; j < nt; j++) {
        tags[j] = ft_tag(ts[j], &fstr[j], &fskip[j]);
        if (!tags[j] && !fstr[j] && !fskip[j]) {
            char bad = (char)toupper((unsigned char)ts[j]);
            free(tags); free(fstr); free(fskip);
            if (bad == 'C')
                return q_err(QE_NYI);
            return q_err(QE_TYPE);
        }
    }
    /* fast path gate: every kept column parses spans in place AND the row text
     * is reachable without boxing — one -RAY_STR's '\n' lines, a RAY_STR
     * vector, or a LIST of STRs. */
    int fast = !embed_nl;
    for (size_t j = 0; j < nt && fast; j++)
        if (fstr[j] || (!fskip[j] && !ft_span_admits(tags[j]))) fast = 0;
    int fmode = 0;
    ray_t** fitems = NULL;
    const char* ftext = NULL;
    size_t ftlen = 0;
    int64_t nrows = 0;
    if (fast) {
        if (y->type == -RAY_STR && memchr(ray_str_ptr(y), '\n', ray_str_len(y))) {
            fmode = FT_ROWS_TEXT;
            ftext = ray_str_ptr(y);
            ftlen = ray_str_len(y);
            int64_t nl = 0;
            for (size_t k = 0; k < ftlen; k++) nl += ftext[k] == '\n';
            nrows = nl + 1;
            if (ftext[ftlen - 1] == '\n') nrows--;   /* the post-terminal-'\n' segment drops */
        } else if (y->type == RAY_STR) {
            fmode = FT_ROWS_STRVEC;
            nrows = q_count(y);
        } else if (y->type == RAY_LIST) {
            fmode = FT_ROWS_LIST;
            nrows = q_count(y);
            ray_t** e = (ray_t**)ray_data(y);
            for (int64_t i = 0; i < nrows; i++)
                if (!e[i] || e[i]->type != -RAY_STR) { fast = 0; fmode = 0; break; }
            fitems = e;
        } else fast = 0;
    }
    if (!fast) fmode = 0;
    int single = 0;
    ray_t* rows = NULL;
    ray_t** rp = NULL;
    if (!fast) {
        rows = ft_rows(y, &single);
        if (!rows || RAY_IS_ERR(rows)) { free(tags); free(fstr); free(fskip); return rows; }
        if (embed_nl) {
            rows = ft_merge_quoted(rows);
            if (!rows || RAY_IS_ERR(rows)) { free(tags); free(fstr); free(fskip); return rows; }
        }
        rp = (ray_t**)ray_data(rows);
        nrows = q_count(rows);
    }
    ray_t* result = NULL;
    if (single) {
        /* one delimited string -> list of parsed atoms */
        ray_t* fields = ray_list_new((int64_t)nt);
        if (RAY_IS_ERR(fields)) { result = fields; goto done; }
        fields = ft_fields(fields, ray_str_ptr(rp[0]), ray_str_len(rp[0]), delim);
        if (RAY_IS_ERR(fields)) { result = fields; goto done; }
        ray_t** fp = (ray_t**)ray_data(fields);
        int64_t nf = q_count(fields);
        ray_t* out = ray_list_new((int64_t)nt);
        if (RAY_IS_ERR(out)) { ray_release(fields); result = out; goto done; }
        ray_t* empty = ray_str("", 0);
        for (size_t j = 0; j < nt && !RAY_IS_ERR(out); j++) {
            if (fskip[j]) continue;
            ray_t* f = (int64_t)j < nf ? fp[j] : empty;     /* borrowed */
            ray_t* a = ft_parse_field(f, tags[j], fstr[j]);
            if (!a || RAY_IS_ERR(a)) { ray_release(empty); ray_release(fields); ray_release(out); result = a ? a : q_err(QE_OOM); goto done; }
            out = ray_list_append(out, a);
            ray_release(a);
        }
        ray_release(empty);
        ray_release(fields);
        result = out;
        goto done;
    }
    {
        /* rows mode: per-column accumulators over the data rows */
        int64_t first = header ? 1 : 0;
        int64_t ndata = nrows - first;
        if (ndata < 0) ndata = 0;
        int64_t nout = 0;
        for (size_t j = 0; j < nt; j++) if (!fskip[j]) nout++;
        if (fast) {
            result = ft_load_fast(y, fitems, ftext, ftlen, fmode, nrows, first, delim,
                                  tags, fskip, nt, nout, ndata);
            if (result && !RAY_IS_ERR(result) && header) {
                /* header: first row = column names -> table */
                ray_t* cols = result;
                ray_t* nmf = ray_list_new((int64_t)nt);
                size_t h0 = 0;
                const char* hp = NULL;
                if (nrows > 0) {
                    if (fmode == FT_ROWS_LIST) { hp = ray_str_ptr(fitems[0]); h0 = ray_str_len(fitems[0]); }
                    else if (fmode == FT_ROWS_TEXT) {
                        hp = ftext;
                        h0 = 0;
                        while (h0 < ftlen && ftext[h0] != '\n') h0++;
                        if (h0 && ftext[h0 - 1] == '\r') h0--;
                    }
                    else hp = ray_str_vec_get(y, 0, &h0);
                }
                if (!RAY_IS_ERR(nmf) && nrows > 0)
                    nmf = ft_fields(nmf, hp ? hp : "", h0, delim);
                if (RAY_IS_ERR(nmf)) { ray_release(cols); result = nmf; goto done; }
                ray_t** np = (ray_t**)ray_data(nmf);
                int64_t nn = q_count(nmf);
                ray_t* tbl = ray_table_new(nout > 0 ? nout : 1);
                int64_t c2 = 0;
                ray_t** cp = (ray_t**)ray_data(cols);
                for (size_t j = 0; j < nt && !RAY_IS_ERR(tbl); j++) {
                    if (fskip[j]) continue;
                    ray_t* nm = (int64_t)j < nn
                        ? q_tok(RAY_SYM, ray_str_ptr(np[j]), ray_str_len(np[j]))
                        : q_tok(RAY_SYM, "", 0);
                    if (!nm || RAY_IS_ERR(nm)) { ray_release(tbl); tbl = nm ? nm : q_err(QE_OOM); break; }
                    tbl = ray_table_add_col(tbl, nm->i64, cp[c2]);
                    ray_release(nm);
                    c2++;
                }
                ray_release(nmf);
                ray_release(cols);
                result = tbl;
            }
            goto done;
        }
        ray_t** acc = (ray_t**)calloc((size_t)(nout > 0 ? nout : 1), sizeof(ray_t*));
        if (!acc) { result = q_err(QE_OOM); goto done; }
        int64_t k = 0;
        for (size_t j = 0; j < nt; j++) {
            if (fskip[j]) continue;
            acc[k] = ray_list_new(ndata > 0 ? ndata : 1);
            if (RAY_IS_ERR(acc[k])) {
                result = acc[k];
                for (int64_t z = 0; z < k; z++) ray_release(acc[z]);
                free(acc);
                goto done;
            }
            k++;
        }
        ray_t* empty = ray_str("", 0);
        for (int64_t i = first; i < nrows; i++) {
            ray_t* fields = ray_list_new((int64_t)nt);
            if (!RAY_IS_ERR(fields))
                fields = ft_fields(fields, ray_str_ptr(rp[i]), ray_str_len(rp[i]), delim);
            if (RAY_IS_ERR(fields)) {
                for (int64_t z = 0; z < nout; z++) ray_release(acc[z]);
                free(acc); ray_release(empty);
                result = fields;
                goto done;
            }
            ray_t** fp = (ray_t**)ray_data(fields);
            int64_t nf = q_count(fields);
            int64_t c = 0;
            for (size_t j = 0; j < nt; j++) {
                if (fskip[j]) continue;
                ray_t* f = (int64_t)j < nf ? fp[j] : empty; /* borrowed */
                acc[c] = ray_list_append(acc[c], f);
                c++;
            }
            ray_release(fields);
        }
        ray_release(empty);
        /* finish columns */
        ray_t* cols = ray_list_new(nout > 0 ? nout : 1);
        for (int64_t z = 0; z < nout && !RAY_IS_ERR(cols); z++) {
            int64_t j = -1, seen = -1;
            for (size_t t = 0; t < nt; t++) {
                if (fskip[t]) continue;
                if (++seen == z) { j = (int64_t)t; break; }
            }
            ray_t* col = ft_finish_col(acc[z], tags[j], fstr[j]);
            if (!col || RAY_IS_ERR(col)) {
                ray_release(cols);
                cols = col ? col : q_err(QE_OOM);
                break;
            }
            cols = ray_list_append(cols, col);
            ray_release(col);
        }
        for (int64_t z = 0; z < nout; z++) ray_release(acc[z]);
        free(acc);
        if (RAY_IS_ERR(cols)) { result = cols; goto done; }
        if (!header) { result = cols; goto done; }
        /* header: first row = column names -> table */
        ray_t* nmf = ray_list_new((int64_t)nt);
        if (!RAY_IS_ERR(nmf) && nrows > 0)
            nmf = ft_fields(nmf, ray_str_ptr(rp[0]), ray_str_len(rp[0]), delim);
        if (RAY_IS_ERR(nmf)) { ray_release(cols); result = nmf; goto done; }
        ray_t** np = (ray_t**)ray_data(nmf);
        int64_t nn = q_count(nmf);
        ray_t* tbl = ray_table_new(nout > 0 ? nout : 1);
        int64_t c2 = 0;
        ray_t** cp = (ray_t**)ray_data(cols);
        for (size_t j = 0; j < nt && !RAY_IS_ERR(tbl); j++) {
            if (fskip[j]) continue;
            /* a name trims as its cells do: through Tok's blank trim */
            ray_t* nm = (int64_t)j < nn
                ? q_tok(RAY_SYM, ray_str_ptr(np[j]), ray_str_len(np[j]))
                : q_tok(RAY_SYM, "", 0);
            if (!nm || RAY_IS_ERR(nm)) { ray_release(tbl); tbl = nm ? nm : q_err(QE_OOM); break; }
            tbl = ray_table_add_col(tbl, nm->i64, cp[c2]);
            ray_release(nm);
            c2++;
        }
        ray_release(nmf);
        ray_release(cols);
        result = tbl;
    }
done:
    ray_release(rows);
    free(tags); free(fstr); free(fskip);
    return result;
}

static ray_t* ft_load_fixed(ray_t* types, ray_t* widths, ray_t* y) {
    const char* ts = ray_str_ptr(types);
    size_t nt = ray_str_len(types);
    if (nt == 0 || (int64_t)nt != q_count(widths))
        return q_err(QE_LENGTH);
    /* widths must be positive (codex P1: a negative width made the slice
     * length negative and reached memcpy as a huge size_t). */
    for (int64_t j = 0; j < (int64_t)nt; j++)
        if (q_type_ivec_get(widths, j) <= 0)
            return q_err(QE_DOMAIN);
    int8_t* tags = (int8_t*)malloc(nt);
    int* fstr = (int*)malloc(nt * sizeof(int));
    int* fskip = (int*)malloc(nt * sizeof(int));
    if (!tags || !fstr || !fskip) { free(tags); free(fstr); free(fskip); return q_err(QE_OOM); }
    for (size_t j = 0; j < nt; j++) {
        tags[j] = ft_tag(ts[j], &fstr[j], &fskip[j]);
        if (!tags[j] && !fstr[j] && !fskip[j]) {
            free(tags); free(fstr); free(fskip);
            return q_err(QE_TYPE);
        }
    }
    int single = 0;
    ray_t* rows = ft_rows(y, &single);
    if (!rows || RAY_IS_ERR(rows)) { free(tags); free(fstr); free(fskip); return rows; }
    ray_t** rp = (ray_t**)ray_data(rows);
    int64_t nrows = q_count(rows);
    int64_t nout = 0;
    for (size_t j = 0; j < nt; j++) if (!fskip[j]) nout++;
    ray_t* result = NULL;
    ray_t** acc = (ray_t**)calloc((size_t)(nout > 0 ? nout : 1), sizeof(ray_t*));
    if (!acc) { result = q_err(QE_OOM); goto done; }
    for (int64_t z = 0; z < nout; z++) {
        acc[z] = ray_list_new(nrows > 0 ? nrows : 1);
        if (RAY_IS_ERR(acc[z])) {
            result = acc[z];
            for (int64_t q = 0; q < z; q++) ray_release(acc[q]);
            free(acc);
            goto done;
        }
    }
    for (int64_t i = 0; i < nrows; i++) {
        const char* p = ray_str_ptr(rp[i]);
        int64_t n = (int64_t)ray_str_len(rp[i]);
        int64_t pos = 0, c = 0;
        for (size_t j = 0; j < nt; j++) {
            int64_t w = q_type_ivec_get(widths, (int64_t)j);
            int64_t s = pos > n ? n : pos;
            int64_t e = pos + w > n ? n : pos + w;
            pos += w;
            if (fskip[j]) continue;
            ray_t* f = ray_str(p + s, (size_t)(e - s));
            if (!f || RAY_IS_ERR(f)) {
                for (int64_t z = 0; z < nout; z++) ray_release(acc[z]);
                free(acc);
                result = f ? f : q_err(QE_OOM);
                goto done;
            }
            acc[c] = ray_list_append(acc[c], f);
            ray_release(f);
            c++;
        }
    }
    {
        ray_t* cols = ray_list_new(nout > 0 ? nout : 1);
        int64_t z = 0;
        for (size_t j = 0; j < nt && !RAY_IS_ERR(cols); j++) {
            if (fskip[j]) continue;
            ray_t* col = ft_finish_col(acc[z], tags[j], fstr[j]);
            if (!col || RAY_IS_ERR(col)) {
                ray_release(cols);
                cols = col ? col : q_err(QE_OOM);
                break;
            }
            cols = ray_list_append(cols, col);
            ray_release(col);
            z++;
        }
        for (int64_t q = 0; q < nout; q++) ray_release(acc[q]);
        free(acc);
        result = cols;
    }
done:
    ray_release(rows);
    free(tags); free(fstr); free(fskip);
    return result;
}

/* ---- Key-Value Pairs: "K f [*] r" 0: string ------------------------------ */
static ray_t* ft_kv(const char* spec, size_t sn, ray_t* y) {
    char ktype = spec[0];
    int star = sn == 4;
    if (star && spec[2] != '*') return q_err(QE_TYPE);
    char fsep = spec[1];
    char rsep = star ? spec[3] : spec[2];
    if (!y || y->type != -RAY_STR)
        return q_err(QE_TYPE);
    int8_t ktag;
    {
        int is_str = 0, is_skip = 0;
        ktag = ft_tag(ktype, &is_str, &is_skip);
        if (!ktag) return q_err(QE_TYPE);
    }
    const char* p = ray_str_ptr(y);
    size_t n = ray_str_len(y);
    ray_t* keys = ray_list_new(4);
    if (RAY_IS_ERR(keys)) return keys;
    ray_t* vals = ray_list_new(4);
    if (RAY_IS_ERR(vals)) { ray_release(keys); return vals; }
    size_t i = 0;
    while (i < n) {
        /* one record: up to rsep (quote-aware in '*' mode) */
        size_t start = i;
        int inq = 0;
        while (i < n && (inq || p[i] != rsep)) {
            if (star && p[i] == '"') inq = !inq;
            i++;
        }
        size_t end = i;
        if (i < n) i++;                                     /* past rsep */
        if (end == start) continue;                         /* empty record */
        /* split at the FIRST fsep */
        size_t f = start;
        while (f < end && p[f] != fsep) f++;
        ray_t* k = ray_str(p + start, f - start);
        size_t vs = f < end ? f + 1 : end;
        ray_t* v;
        if (star && vs < end && p[vs] == '"' && p[end - 1] == '"' && end - vs >= 2) {
            /* quoted value: strip the outer quotes, un-double inner ones */
            char* vb = (char*)malloc(end - vs);
            size_t vl = 0;
            if (!vb) { ray_release(k); ray_release(keys); ray_release(vals); return q_err(QE_OOM); }
            for (size_t t = vs + 1; t < end - 1; t++) {
                if (p[t] == '"' && t + 1 < end - 1 && p[t + 1] == '"') { vb[vl++] = '"'; t++; }
                else vb[vl++] = p[t];
            }
            v = ray_str(vb, vl);
            free(vb);
        } else v = ray_str(p + vs, end - vs);
        if (!k || RAY_IS_ERR(k) || !v || RAY_IS_ERR(v)) {
            if (k && !RAY_IS_ERR(k)) ray_release(k);
            if (v && !RAY_IS_ERR(v)) ray_release(v);
            ray_release(keys); ray_release(vals);
            return q_err(QE_OOM);
        }
        ray_t* ka = q_dollar_tok(ktag, k);
        ray_release(k);
        if (!ka || RAY_IS_ERR(ka)) { ray_release(v); ray_release(keys); ray_release(vals); return ka ? ka : q_err(QE_OOM); }
        keys = ray_list_append(keys, ka);
        ray_release(ka);
        vals = ray_list_append(vals, v);
        ray_release(v);
        if (RAY_IS_ERR(keys) || RAY_IS_ERR(vals)) {
            ray_t* err = RAY_IS_ERR(keys) ? keys : vals;
            if (!RAY_IS_ERR(keys)) ray_release(keys);
            if (!RAY_IS_ERR(vals)) ray_release(vals);
            return err;
        }
    }
    ray_t* kv = q_list_collapse(keys);                      /* typed key vector */
    ray_release(keys);
    if (!kv || RAY_IS_ERR(kv)) { ray_release(vals); return kv ? kv : q_err(QE_OOM); }
    ray_t* out = ray_list_new(2);
    if (RAY_IS_ERR(out)) { ray_release(kv); ray_release(vals); return out; }
    out = ray_list_append(out, kv);
    ray_release(kv);
    if (RAY_IS_ERR(out)) { ray_release(vals); return out; }
    out = ray_list_append(out, vals);
    ray_release(vals);
    return out;
}


/* ---- the `0:` dispatcher -------------------------------------------------- */
static ray_t* io_filetext_impl(ray_t* x, ray_t* y);
/* x-normalize preserving the bare-vs-ENLISTED delimiter distinction the
 * charv model carries natively: char ATOM -> 1-char STR (bare delim); charv
 * len-1 -> boxed 1-list of a 1-char STR (the legacy enlisted form, header
 * row); other charv -> STR (types/kv spec); LIST -> per-element.  Owned. */
/* The head of a LIST x is the TYPE STRING: a charv normalizes to plain text (no
 * enlist-collapse — that rule belongs to the delimiter beside it, and applying
 * it here lost the one-column load), and every other shape passes through for
 * io_filetext_impl's -RAY_STR test to judge, so a char ATOM is refused. */
static ray_t* ft_norm_types(ray_t* x) {
    if (x && x->type == RAY_CHARV) return q_str_of_charv(x);
    if (x) ray_retain(x);
    return x;
}
static ray_t* ft_norm_x(ray_t* x) {
    if (x && x->type == -RAY_CHARV) { char c = (char)x->u8; return ray_str(&c, 1); }
    if (x && x->type == RAY_CHARV) {
        if (q_count(x) == 1) {
            ray_t* s = q_str_of_charv(x);
            if (!s || RAY_IS_ERR(s)) return s;
            ray_t* l = ray_list_new(1);
            if (!l || RAY_IS_ERR(l)) { ray_release(s); return l; }
            l = ray_list_append(l, s);
            ray_release(s);
            return l;
        }
        return q_str_of_charv(x);
    }
    if (x && x->type == RAY_LIST) {
        int64_t n = q_count(x);
        ray_t** e = (ray_t**)ray_data(x);
        ray_t* out = ray_list_new(n > 0 ? n : 1);
        if (!out || RAY_IS_ERR(out)) return out;
        for (int64_t i = 0; i < n; i++) {
            ray_t* c = i == 0 ? ft_norm_types(e[i]) : ft_norm_x(e[i]);
            if (!c) { ray_retain(e[i]); c = e[i]; }
            if (RAY_IS_ERR(c)) { ray_release(out); return c; }
            out = ray_list_append(out, c);
            ray_release(c);
            if (RAY_IS_ERR(out)) return out;
        }
        return out;
    }
    if (x) ray_retain(x);
    return x;
}
ray_t* q_io_filetext_wrap(ray_t* x, ray_t* y) {
    ray_t* xs = ft_norm_x(x); ray_t* ys = q_str_in(y);
    ray_t* r = io_filetext_impl(xs, ys);
    ray_release(xs); ray_release(ys);
    return q_str_charv_out(r);              /* parsed strings cross as charv */
}
static ray_t* io_filetext_impl(ray_t* x, ray_t* y) {
    if (!x) return q_err(QE_TYPE);
    if (x->type == -RAY_SYM) return ft_save_text(x, y);
    if (x->type == -RAY_STR) {
        const char* s = ray_str_ptr(x);
        size_t n = ray_str_len(x);
        if (n == 1) return ft_prepare(s[0], y);
        char k = (char)toupper((unsigned char)s[0]);
        if ((n == 3 || n == 4) && (k == 'S' || k == 'I' || k == 'J'))
            return ft_kv(s, n, y);
        return q_err(QE_TYPE);
    }
    if (x->type == RAY_LIST && (q_count(x) == 2 || q_count(x) == 3)) {
        ray_t** e = (ray_t**)ray_data(x);
        if (e[0] && e[0]->type == -RAY_STR) {
            if (q_count(x) == 2 && q_type_is_int_vec(e[1]))
                return ft_load_fixed(e[0], e[1], y);
            return ft_load_csv(e[0], e[1], q_count(x) == 3 ? e[2] : NULL, y);
        }
    }
    return q_err(QE_TYPE);
}
