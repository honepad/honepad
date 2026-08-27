import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class MiniJson {
    public static Object parse(String text) {
        Parser parser = new Parser(text);
        Object value = parser.parseValue();
        parser.skipWs();
        if (!parser.done()) {
            throw new IllegalArgumentException("trailing json at " + parser.pos);
        }
        return value;
    }

    public static String stringify(Object value) {
        StringBuilder out = new StringBuilder();
        write(out, value);
        return out.toString();
    }

    static void write(StringBuilder out, Object value) {
        if (value == null) {
            out.append("null");
            return;
        }
        if (value instanceof Boolean) {
            out.append(value.toString());
            return;
        }
        if (value instanceof Number) {
            if (value instanceof Double || value instanceof Float) {
                double number = ((Number) value).doubleValue();
                if (!Double.isInfinite(number) && number == Math.rint(number)) {
                    out.append((long) number);
                } else {
                    out.append(value.toString());
                }
            } else {
                out.append(((Number) value).longValue());
            }
            return;
        }
        if (value instanceof String) {
            out.append('"');
            escape(out, (String) value);
            out.append('"');
            return;
        }
        if (value instanceof List) {
            out.append('[');
            List<?> list = (List<?>) value;
            for (int i = 0; i < list.size(); i++) {
                if (i > 0) {
                    out.append(',');
                }
                write(out, list.get(i));
            }
            out.append(']');
            return;
        }
        if (value instanceof Map) {
            out.append('{');
            boolean first = true;
            for (Map.Entry<?, ?> entry : ((Map<?, ?>) value).entrySet()) {
                if (!first) {
                    out.append(',');
                }
                first = false;
                write(out, String.valueOf(entry.getKey()));
                out.append(':');
                write(out, entry.getValue());
            }
            out.append('}');
            return;
        }
        throw new IllegalArgumentException("cannot stringify " + value.getClass().getName());
    }

    static void escape(StringBuilder out, String text) {
        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            switch (ch) {
                case '"':
                    out.append("\\\"");
                    break;
                case '\\':
                    out.append("\\\\");
                    break;
                case '\b':
                    out.append("\\b");
                    break;
                case '\f':
                    out.append("\\f");
                    break;
                case '\n':
                    out.append("\\n");
                    break;
                case '\r':
                    out.append("\\r");
                    break;
                case '\t':
                    out.append("\\t");
                    break;
                default:
                    if (ch < 0x20) {
                        out.append(String.format("\\u%04x", (int) ch));
                    } else {
                        out.append(ch);
                    }
            }
        }
    }

    static final class Parser {
        final String s;
        int pos;

        Parser(String s) {
            this.s = s;
        }

        boolean done() {
            return pos >= s.length();
        }

        void skipWs() {
            while (pos < s.length()) {
                char ch = s.charAt(pos);
                if (ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t') {
                    break;
                }
                pos++;
            }
        }

        char peek() {
            skipWs();
            if (pos >= s.length()) {
                throw new IllegalArgumentException("unexpected end of json");
            }
            return s.charAt(pos);
        }

        char next() {
            skipWs();
            if (pos >= s.length()) {
                throw new IllegalArgumentException("unexpected end of json");
            }
            return s.charAt(pos++);
        }

        Object parseValue() {
            char ch = peek();
            if (ch == '{') {
                return parseObject();
            }
            if (ch == '[') {
                return parseArray();
            }
            if (ch == '"') {
                return parseString();
            }
            if (ch == 't' || ch == 'f') {
                return parseBool();
            }
            if (ch == 'n') {
                parseLiteral("null");
                return null;
            }
            if (ch == '-' || (ch >= '0' && ch <= '9')) {
                return parseNumber();
            }
            throw new IllegalArgumentException("bad json at " + pos);
        }

        Map<String, Object> parseObject() {
            expect('{');
            Map<String, Object> map = new LinkedHashMap<>();
            skipWs();
            if (peek() == '}') {
                pos++;
                return map;
            }
            while (true) {
                String key = parseString();
                expect(':');
                map.put(key, parseValue());
                skipWs();
                char ch = next();
                if (ch == '}') {
                    return map;
                }
                if (ch != ',') {
                    throw new IllegalArgumentException("expected comma at " + (pos - 1));
                }
            }
        }

        List<Object> parseArray() {
            expect('[');
            List<Object> list = new ArrayList<>();
            skipWs();
            if (peek() == ']') {
                pos++;
                return list;
            }
            while (true) {
                list.add(parseValue());
                skipWs();
                char ch = next();
                if (ch == ']') {
                    return list;
                }
                if (ch != ',') {
                    throw new IllegalArgumentException("expected comma at " + (pos - 1));
                }
            }
        }

        String parseString() {
            expect('"');
            StringBuilder out = new StringBuilder();
            while (pos < s.length()) {
                char ch = s.charAt(pos++);
                if (ch == '"') {
                    return out.toString();
                }
                if (ch == '\\') {
                    if (pos >= s.length()) {
                        throw new IllegalArgumentException("unterminated escape");
                    }
                    char esc = s.charAt(pos++);
                    switch (esc) {
                        case '"':
                        case '\\':
                        case '/':
                            out.append(esc);
                            break;
                        case 'b':
                            out.append('\b');
                            break;
                        case 'f':
                            out.append('\f');
                            break;
                        case 'n':
                            out.append('\n');
                            break;
                        case 'r':
                            out.append('\r');
                            break;
                        case 't':
                            out.append('\t');
                            break;
                        case 'u':
                            if (pos + 4 > s.length()) {
                                throw new IllegalArgumentException("bad unicode escape");
                            }
                            int code = Integer.parseInt(s.substring(pos, pos + 4), 16);
                            out.append((char) code);
                            pos += 4;
                            break;
                        default:
                            throw new IllegalArgumentException("bad escape \\" + esc);
                    }
                } else {
                    out.append(ch);
                }
            }
            throw new IllegalArgumentException("unterminated string");
        }

        Boolean parseBool() {
            if (s.startsWith("true", pos)) {
                pos += 4;
                return Boolean.TRUE;
            }
            if (s.startsWith("false", pos)) {
                pos += 5;
                return Boolean.FALSE;
            }
            throw new IllegalArgumentException("bad bool at " + pos);
        }

        void parseLiteral(String lit) {
            if (!s.startsWith(lit, pos)) {
                throw new IllegalArgumentException("expected " + lit + " at " + pos);
            }
            pos += lit.length();
        }

        Number parseNumber() {
            int start = pos;
            if (s.charAt(pos) == '-') {
                pos++;
            }
            while (pos < s.length() && s.charAt(pos) >= '0' && s.charAt(pos) <= '9') {
                pos++;
            }
            boolean frac = false;
            if (pos < s.length() && s.charAt(pos) == '.') {
                frac = true;
                pos++;
                while (pos < s.length() && s.charAt(pos) >= '0' && s.charAt(pos) <= '9') {
                    pos++;
                }
            }
            if (pos < s.length() && (s.charAt(pos) == 'e' || s.charAt(pos) == 'E')) {
                frac = true;
                pos++;
                if (pos < s.length() && (s.charAt(pos) == '+' || s.charAt(pos) == '-')) {
                    pos++;
                }
                while (pos < s.length() && s.charAt(pos) >= '0' && s.charAt(pos) <= '9') {
                    pos++;
                }
            }
            String raw = s.substring(start, pos);
            if (frac) {
                return Double.valueOf(raw);
            }
            return Long.valueOf(raw);
        }

        void expect(char wanted) {
            char ch = next();
            if (ch != wanted) {
                throw new IllegalArgumentException("expected " + wanted + " at " + (pos - 1));
            }
        }
    }
}
