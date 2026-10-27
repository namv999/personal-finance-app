package com.pfm.backend.ai;

import java.util.regex.Pattern;

public final class SensitiveMasker {
    private static final int FLAGS = Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE;
    private static final Pattern BALANCE = Pattern.compile(
            "\\b(?:số dư|so du|sd|balance)\\s*(?:cuối)?\\s*[:=]?\\s*[+-]?\\d[\\d.,]*\\s*(?:vnd|vnđ|đ)?", FLAGS);
    private static final Pattern ACCOUNT_KEY = Pattern.compile("\\b(stk|tk|a/c|acc)\\s*[:.]?\\s*\\d{6,}", FLAGS);
    private static final Pattern CARD = Pattern.compile("(?<!\\d)(?:\\d{4}[ -]){3}\\d{4}(?!\\d)");
    private static final Pattern PHONE = Pattern.compile("(?<!\\d)(?:\\+84|84|0)\\d{9}(?!\\d)");
    private static final Pattern LONG_DIGITS = Pattern.compile("(?<!\\d)\\d{10,19}(?!\\d)");
    private static final Pattern PARTIAL = Pattern.compile("[*xX]{2,}\\d{2,}");

    private SensitiveMasker() {
    }

    public static String mask(String value) {
        if (value == null)
            return "";
        value = BALANCE.matcher(value).replaceAll("[SO_DU]");
        value = ACCOUNT_KEY.matcher(value).replaceAll("$1 [SO]");
        value = CARD.matcher(value).replaceAll("[THE]");
        value = PHONE.matcher(value).replaceAll("[SDT]");
        value = LONG_DIGITS.matcher(value).replaceAll("[SO]");
        return PARTIAL.matcher(value).replaceAll("****");
    }
}
