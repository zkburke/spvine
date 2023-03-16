const std = @import("std");
const Tokenizer = @This();

source: []const u8,
index: u32,
state: enum {
    start,
    identifier,
    slash,
    single_comment,
    multi_comment,
    literal_integer,
    directive_start,
} = .start,
is_directive: bool = false,

pub fn next(self: *Tokenizer) ?Token {    
    var token = Token { .start = self.index, .end = self.index, .tag = .end };

    var multi_comment_level: usize = 0;

    while (self.index < self.source.len) : (self.index += 1) {
        const char = self.source[self.index];

        switch (self.state) {
            .start => switch (char) {
                0 => return null,
                ' ', '\t', => {
                    token.start = self.index + 1;
                },
                '\r', '\n' => {
                    if (!self.is_directive)
                    {
                        token.start = self.index + 1;
                    }
                    else 
                    {
                        token.tag = .directive_end;
                        self.is_directive = false;
                        self.index += 1;
                        break;
                    }
                },
                'a'...'z', 'A'...'Z', '_', => {
                    self.state = .identifier;
                },
                '#' => {
                    self.state = .directive_start;
                },
                '0'...'9' => {
                    self.state = .literal_integer;
                },
                '/' => {
                    self.state = .slash;
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
                    token.tag = .plus;
                    self.index += 1;
                    break;
                },
                '-' => {
                    token.tag = .minus;
                    self.index += 1;
                    break;
                },
                '=' => {
                    token.tag = .equals;
                    self.index += 1;
                    break;
                },
                else => {},
            },
            .directive_start => switch (char) {
                'a'...'z', 'A'...'Z', '_', => {},
                else => {
                    const string = self.source[token.start..self.index];

                    if (Token.getDirective(string)) |directive_tag|
                    {
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

                    if (Token.getKeyword(string)) |keyword_tag|
                    {
                        token.tag = keyword_tag;
                    }
                    else 
                    {
                        token.tag = .identifier;
                    }

                    self.state = .start;

                    break;
                },
            },
            .slash => switch (char) {
                '/' => {
                    self.state = .single_comment;
                },
                '*' => {
                    self.state = .multi_comment;
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
                    if (self.source[self.index + 1] == '/')
                    {
                        self.index += 1;

                        if (multi_comment_level == 0)
                        {
                            self.state = .start;
                        }
                        else 
                        {
                            multi_comment_level -= 1;
                        }
                    }
                },
                '/' => {
                    if (self.source[self.index + 1] == '*')
                    {
                        self.index += 1;
                        multi_comment_level += 1;
                    }
                },
                else => {},
            },
            .literal_integer => switch (char) {
                '0'...'9' => {},
                else => {
                    token.tag = .literal_integer;
                    self.state = .start;

                    break;
                },
            },
        }
    }

    if (token.tag == .end or self.index > self.source.len)
    {
        return null;
    }

    token.end = self.index;

    const log = std.log.scoped(.tokenizer);

    log.info("token: {s}", .{ @tagName(token.tag) });

    return token;
}

pub const Token = struct {
    start: u32,
    end: u32,
    tag: Tag,

    pub const Tag = enum {
        end,
        directive_identifier,
        directive_literal_integer,
        directive_literal_real,
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
        keyword_void,
        keyword_int,
        keyword_float,
        keyword_if,
        keyword_else,
        keyword_return,
        literal_integer,
        identifier,
        left_brace,
        right_brace,
        left_paren,
        right_paren,
        semicolon,
        comma,
        period,
        plus,
        minus,
        equals,

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .end,
                .identifier,
                .literal_integer,
                .directive_identifier,
                .directive_literal_integer,
                .directive_literal_real,
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
                .keyword_void => "void",
                .keyword_int => "int",
                .keyword_float => "float",
                .keyword_if => "if",
                .keyword_else => "else",
                .keyword_return => "return",
                .left_brace => "{",
                .right_brace => "}",
                .left_paren => "(",
                .right_paren => ")",
                .semicolon => ";",
                .comma => ",",
                .period => ".",
                .plus => "+",
                .minus => "-",
                .equals => "=",
            };
        }
    };

    pub fn lexeme(token: Token) ?[]const u8
    {
        return token.tag.lexeme();
    }

    pub fn getKeyword(string: []const u8) ?Tag {
        return keywords.get(string);
    }

    pub fn getDirective(string: []const u8) ?Tag {
        return directives.get(string);
    }

    const keywords = std.ComptimeStringMap(Tag, .{
        .{ "void", .keyword_void },
        .{ "int", .keyword_int },
        .{ "float", .keyword_float },
        .{ "if", .keyword_if },
        .{ "else", .keyword_else },
        .{ "return", .keyword_return },
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