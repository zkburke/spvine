//! Implements the lexical analysis stage of the frontend

source: []const u8,
index: u32,
state: enum {
    start,
    identifier,
    forward_slash,
    backward_slash,
    plus,
    minus,
    asterisk,
    equals,
    single_comment,
    multi_comment,
    literal_number,
    directive_start,
} = .start,
is_directive: bool = false,

pub fn next(self: *Tokenizer) ?Token {
    var token = Token{ .start = self.index, .end = self.index, .tag = .end };

    var multi_comment_level: usize = 0;

    while (self.index < self.source.len) : (self.index += 1) {
        const char = self.source[self.index];

        switch (self.state) {
            .start => switch (char) {
                0 => return null,
                ' ',
                '\t',
                => {
                    token.start = self.index + 1;
                },
                '\r', '\n' => {
                    if (!self.is_directive) {
                        token.start = self.index + 1;
                    } else {
                        token.tag = .directive_end;
                        self.is_directive = false;
                        self.index += 1;
                        break;
                    }
                },
                'a'...'z',
                'A'...'Z',
                '_',
                => {
                    self.state = .identifier;
                },
                '#' => {
                    self.state = .directive_start;
                },
                '0'...'9' => {
                    self.state = .literal_number;
                },
                '/' => {
                    self.state = .forward_slash;
                },
                '\\' => {
                    self.state = .backward_slash;
                },
                '{' => {
                    token.tag = .left_brace;
                    self.index += 1;
                    break;
                },
                '}' => {
                    token.tag = .right_brace;
                    self.index += 1;
                    break;
                },
                '[' => {
                    token.tag = .left_bracket;
                    self.index += 1;
                    break;
                },
                ']' => {
                    token.tag = .right_bracket;
                    self.index += 1;
                    break;
                },
                '(' => {
                    token.tag = .left_paren;
                    self.index += 1;
                    break;
                },
                ')' => {
                    token.tag = .right_paren;
                    self.index += 1;
                    break;
                },
                ';' => {
                    token.tag = .semicolon;
                    self.index += 1;
                    break;
                },
                ',' => {
                    token.tag = .comma;
                    self.index += 1;
                    break;
                },
                '.' => {
                    token.tag = .period;
                    self.index += 1;
                    break;
                },
                '+' => {
                    self.state = .plus;
                },
                '-' => {
                    self.state = .minus;
                },
                '=' => {
                    self.state = .equals;
                },
                '*' => {
                    self.state = .asterisk;
                },
                else => {},
            },
            .directive_start => switch (char) {
                'a'...'z',
                'A'...'Z',
                '_',
                => {},
                else => {
                    const string = self.source[token.start..self.index];

                    if (Token.getDirective(string)) |directive_tag| {
                        token.tag = directive_tag;
                    }

                    self.state = .start;
                    self.is_directive = true;

                    break;
                },
            },
            .identifier => switch (char) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                else => {
                    const string = self.source[token.start..self.index];

                    if (Token.getKeyword(string)) |keyword_tag| {
                        token.tag = keyword_tag;
                    } else {
                        token.tag = .identifier;
                    }

                    self.state = .start;

                    break;
                },
            },
            .literal_number => switch (char) {
                '0'...'9', '.', 'f', 'F', 'd', 'D', 'b', 'B', 'o', 'O', 'x', 'X', 'u', 'U' => {},
                else => {
                    token.tag = .literal_number;
                    self.state = .start;
                    break;
                },
            },
            .plus => switch (char) {
                '=' => {
                    token.tag = .plus_equals;
                    self.state = .start;
                    self.index += 1;
                    break;
                },
                else => {
                    token.tag = .plus;
                    self.state = .start;
                    break;
                },
            },
            .minus => switch (char) {
                '=' => {
                    token.tag = .minus_equals;
                    self.state = .start;
                    self.index += 1;
                    break;
                },
                else => {
                    token.tag = .minus;
                    self.state = .start;
                    break;
                },
            },
            .asterisk => switch (char) {
                '=' => {
                    token.tag = .asterisk_equals;
                    self.state = .start;
                    self.index += 1;
                    break;
                },
                else => {
                    token.tag = .asterisk;
                    self.state = .start;
                    break;
                },
            },
            .equals => switch (char) {
                '=' => {
                    token.tag = .equals_equals;
                    self.state = .start;
                    self.index += 1;
                    break;
                },
                else => {
                    token.tag = .equals;
                    self.state = .start;
                    break;
                },
            },
            .forward_slash => switch (char) {
                '/' => {
                    self.state = .single_comment;
                },
                '*' => {
                    self.state = .multi_comment;
                },
                '=' => {
                    token.tag = .forward_slash_equals;
                    self.state = .start;
                    self.index += 1;
                    break;
                },
                else => {
                    token.tag = .forward_slash;
                    self.state = .start;
                    break;
                },
            },
            .backward_slash => switch (char) {
                '\n', '\r' => {
                    self.state = .start;
                },
                else => {},
            },
            .single_comment => switch (char) {
                '\n' => {
                    self.state = .start;
                    token.start = self.index + 1;
                },
                else => {},
            },
            .multi_comment => switch (char) {
                '*' => {
                    if (self.source[self.index + 1] == '/') {
                        self.index += 1;

                        if (multi_comment_level == 0) {
                            self.state = .start;
                        } else {
                            multi_comment_level -= 1;
                        }
                    }
                },
                '/' => {
                    if (self.source[self.index + 1] == '*') {
                        self.index += 1;
                        multi_comment_level += 1;
                    }
                },
                else => {},
            },
        }
    }

    if (token.tag == .end or self.index > self.source.len) {
        return null;
    }

    token.end = self.index;

    return token;
}

pub const Token = struct {
    start: u32,
    end: u32,
    tag: Tag,

    pub const Tag = enum(u8) {
        end,
        directive_define,
        directive_undef,
        directive_if,
        directive_ifdef,
        directive_ifndef,
        directive_else,
        directive_elif,
        directive_endif,
        directive_error,
        directive_pragma,
        directive_extension,
        directive_version,
        directive_line,
        directive_end,

        keyword_layout,
        keyword_restrict,
        keyword_readonly,
        keyword_writeonly,
        keyword_volatile,
        keyword_coherent,

        keyword_attribute,
        keyword_varying,
        keyword_buffer,
        keyword_uniform,
        keyword_shared,
        keyword_const,

        keyword_flat,
        keyword_smooth,

        keyword_struct,

        keyword_void,
        keyword_int,
        keyword_uint,
        keyword_float,
        keyword_double,
        keyword_bool,
        keyword_true,
        keyword_false,

        keyword_vec2,
        keyword_vec3,
        keyword_vec4,

        keyword_if,
        keyword_else,
        keyword_break,
        keyword_continue,
        keyword_do,
        keyword_for,
        keyword_while,
        keyword_switch,
        keyword_case,
        keyword_default,
        keyword_return,
        keyword_discard,
        keyword_in,
        keyword_out,
        keyword_inout,

        literal_number,
        identifier,
        left_brace,
        right_brace,
        left_bracket,
        right_bracket,
        left_paren,
        right_paren,
        semicolon,
        comma,
        period,
        plus,
        plus_equals,
        minus,
        minus_equals,
        equals,
        equals_equals,
        asterisk,
        asterisk_equals,
        forward_slash,
        forward_slash_equals,

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .end,
                .identifier,
                .literal_number,
                .directive_end,
                => null,
                .directive_define => "#define",
                .directive_undef => "#undef",
                .directive_if => "#if",
                .directive_ifdef => "#ifdef",
                .directive_ifndef => "#ifndef",
                .directive_else => "#else",
                .directive_elif => "#elif",
                .directive_endif => "#endif",
                .directive_error => "#error",
                .directive_pragma => "#pragma",
                .directive_extension => "#extension",
                .directive_version => "#version",
                .directive_line => "#line",

                .keyword_layout => "layout",
                .keyword_restrict => "restrict",
                .keyword_readonly => "readonly",
                .keyword_writeonly => "writeonly",
                .keyword_volatile => "volatile",
                .keyword_coherent => "coherent",

                .keyword_attribute => "attribute",
                .keyword_varying => "varying",
                .keyword_buffer => "buffer",
                .keyword_uniform => "uniform",
                .keyword_shared => "shared",
                .keyword_const => "const",

                .keyword_flat => "flat",
                .keyword_smooth => "smooth",

                .keyword_struct => "struct",

                .keyword_void => "void",
                .keyword_int => "int",
                .keyword_uint => "uint",
                .keyword_float => "float",
                .keyword_double => "double",
                .keyword_bool => "bool",
                .keyword_true => "true",
                .keyword_false => "false",

                .keyword_vec2 => "vec2",
                .keyword_vec3 => "vec3",
                .keyword_vec4 => "vec4",

                .keyword_if => "if",
                .keyword_else => "else",
                .keyword_break => "break",
                .keyword_continue => "continue",
                .keyword_do => "do",
                .keyword_for => "for",
                .keyword_while => "while",
                .keyword_switch => "switch",
                .keyword_case => "case",
                .keyword_default => "default",
                .keyword_return => "return",
                .keyword_discard => "discard",
                .keyword_in => "in",
                .keyword_out => "out",
                .keyword_inout => "inout",

                .left_brace => "{",
                .right_brace => "}",
                .left_bracket => "[",
                .right_bracket => "]",
                .left_paren => "(",
                .right_paren => ")",
                .semicolon => ";",
                .comma => ",",
                .period => ".",
                .plus => "+",
                .plus_equals => "+=",
                .minus => "-",
                .minus_equals => "-=",
                .equals => "=",
                .equals_equals => "==",
                .asterisk => "*",
                .asterisk_equals => "*=",
                .forward_slash => "/",
                .forward_slash_equals => "/=",
            };
        }
    };

    pub fn lexeme(token: Token) ?[]const u8 {
        return token.tag.lexeme();
    }

    pub fn getKeyword(string: []const u8) ?Tag {
        return keywords.get(string);
    }

    pub fn getDirective(string: []const u8) ?Tag {
        return directives.get(string);
    }

    const keywords = std.ComptimeStringMap(Tag, .{
        .{ "layout", .keyword_layout },
        .{ "restrict", .keyword_restrict },
        .{ "readonly", .keyword_readonly },
        .{ "writeonly", .keyword_writeonly },
        .{ "volatile", .keyword_volatile },
        .{ "coherent", .keyword_coherent },

        .{ "attribute", .keyword_attribute },
        .{ "varying", .keyword_varying },
        .{ "buffer", .keyword_buffer },
        .{ "uniform", .keyword_uniform },
        .{ "shared", .keyword_shared },
        .{ "const", .keyword_const },

        .{ "flat", .keyword_flat },
        .{ "smooth", .keyword_smooth },

        .{ "struct", .keyword_struct },

        .{ "void", .keyword_void },
        .{ "int", .keyword_int },
        .{ "uint", .keyword_uint },
        .{ "float", .keyword_float },
        .{ "double", .keyword_double },
        .{ "bool", .keyword_bool },
        .{ "true", .keyword_true },
        .{ "false", .keyword_false },

        .{ "vec2", .keyword_vec2 },
        .{ "vec3", .keyword_vec3 },
        .{ "vec4", .keyword_vec4 },

        .{ "if", .keyword_if },
        .{ "else", .keyword_else },
        .{ "break", .keyword_break },
        .{ "continue", .keyword_continue },
        .{ "do", .keyword_do },
        .{ "for", .keyword_for },
        .{ "while", .keyword_while },
        .{ "switch", .keyword_switch },
        .{ "case", .keyword_case },
        .{ "default", .keyword_default },
        .{ "return", .keyword_return },
        .{ "discard", .keyword_discard },
        .{ "in", .keyword_in },
        .{ "out", .keyword_out },
        .{ "inout", .keyword_inout },
    });

    const directives = std.ComptimeStringMap(Tag, .{
        .{ "#define", .directive_define },
        .{ "#undef", .directive_undef },
        .{ "#if", .directive_if },
        .{ "#ifdef", .directive_ifdef },
        .{ "#ifndef", .directive_ifdef },
        .{ "#else", .directive_else },
        .{ "#elif", .directive_elif },
        .{ "#endif", .directive_endif },
        .{ "#error", .directive_error },
        .{ "#pragma", .directive_pragma },
        .{ "#extension", .directive_pragma },
        .{ "#version", .directive_version },
        .{ "#line", .directive_line },
    });
};

test "Basic Vertex shader" {
    const expect = std.testing.expect;

    const source =
        \\#version 450
        \\
        \\void main() {
        \\gl_Position = vec4(0.5, 0.5, 0.5, 1.0);
        \\}
    ;

    var tokenizer = Tokenizer{
        .source = source,
        .index = 0,
    };

    try expect(tokenizer.next().?.tag == .directive_version);
    try expect(tokenizer.next().?.tag == .literal_number);
    try expect(tokenizer.next().?.tag == .directive_end);

    try expect(tokenizer.next().?.tag == .keyword_void);
    try expect(tokenizer.next().?.tag == .identifier);
    try expect(tokenizer.next().?.tag == .left_paren);
    try expect(tokenizer.next().?.tag == .right_paren);
    try expect(tokenizer.next().?.tag == .left_brace);
    try expect(tokenizer.next().?.tag == .identifier);
    try expect(tokenizer.next().?.tag == .equals);
    try expect(tokenizer.next().?.tag == .keyword_vec4);
    try expect(tokenizer.next().?.tag == .left_paren);
    try expect(tokenizer.next().?.tag == .literal_number);
    try expect(tokenizer.next().?.tag == .comma);
    try expect(tokenizer.next().?.tag == .literal_number);
    try expect(tokenizer.next().?.tag == .comma);
    try expect(tokenizer.next().?.tag == .literal_number);
    try expect(tokenizer.next().?.tag == .comma);
    try expect(tokenizer.next().?.tag == .literal_number);
    try expect(tokenizer.next().?.tag == .right_paren);
    try expect(tokenizer.next().?.tag == .semicolon);
    try expect(tokenizer.next().?.tag == .right_brace);
    try expect(tokenizer.next() == null);
}

const std = @import("std");
const Tokenizer = @This();
