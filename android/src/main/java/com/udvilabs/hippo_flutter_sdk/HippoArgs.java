package com.udvilabs.hippo_flutter_sdk;

import java.util.HashMap;
import java.util.Map;

/** The plugin's helpers that don't touch the Hippo SDK (a compile-only dependency), so they're unit-tested without it. */
final class HippoArgs {
    private HippoArgs() {
    }

    /** A key, secret or token as a log shows it: its first four characters and its length ("f3a4…(32)"). */
    static String mask(Object value) {
        String text = value == null ? "" : value.toString();
        if (text.isEmpty()) {
            return "(none)";
        }
        return text.length() <= 4 ? "…(" + text.length() + ")" : text.substring(0, 4) + "…(" + text.length() + ")";
    }

    /**
     * A push message's data from Dart as the Hippo SDK takes it: string keys and string values (a missing value is
     * ""). Null when the arguments aren't a map.
     */
    static Map<String, String> stringMap(Object arguments) {
        if (!(arguments instanceof Map)) {
            return null;
        }
        Map<String, String> data = new HashMap<>();
        for (Map.Entry<?, ?> entry : ((Map<?, ?>) arguments).entrySet()) {
            if (entry.getKey() != null) {
                data.put(entry.getKey().toString(), entry.getValue() == null ? "" : entry.getValue().toString());
            }
        }
        return data;
    }
}
