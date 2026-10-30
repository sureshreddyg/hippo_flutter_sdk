package com.udvilabs.hippo_flutter_sdk;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import org.junit.Test;

/** The plugin's Hippo-free helpers (Hippo is a compile-only dependency, so the plugin itself isn't unit-tested here). */
public class HippoArgsTest {
    @Test
    public void masksKeysAndTokens() {
        assertEquals("f3a4…(32)", HippoArgs.mask("f3a4213c67b4feb32bef5bc1db86434e"));
        assertEquals("…(3)", HippoArgs.mask("abc"));
        assertEquals("(none)", HippoArgs.mask(""));
        assertEquals("(none)", HippoArgs.mask(null));
    }

    @Test
    public void pushDataBecomesStrings() {
        Map<String, Object> data = new HashMap<>();
        data.put("push_source", "FUGU");
        data.put("channel_id", 42);
        data.put("title", null);
        Map<String, String> strings = HippoArgs.stringMap(data);
        assertEquals("FUGU", strings.get("push_source"));
        assertEquals("42", strings.get("channel_id"));
        assertEquals("", strings.get("title"));
    }

    @Test
    public void argumentsThatAreNotAMapGiveNull() {
        assertNull(HippoArgs.stringMap("FUGU"));
        assertNull(HippoArgs.stringMap(null));
    }

    @Test
    public void aChatCountNeedsItsTransactionAndTheOtherUser() {
        assertNull(HippoArgs.missingForChatCount("AK806", Collections.singletonList("driver12")));
        assertEquals("transactionId", HippoArgs.missingForChatCount("", Collections.singletonList("driver12")));
        assertEquals("transactionId", HippoArgs.missingForChatCount(null, Collections.singletonList("driver12")));
        assertEquals("otherUserUniqueKeys", HippoArgs.missingForChatCount("AK806", Collections.emptyList()));
        assertEquals("otherUserUniqueKeys", HippoArgs.missingForChatCount("AK806", Collections.singletonList("")));
        assertEquals("otherUserUniqueKeys", HippoArgs.missingForChatCount("AK806", null));
    }

    @Test
    public void aChatCountGoesToDartWithItsTransaction() {
        Map<String, Object> event = HippoArgs.chatCount("AK806", 2);
        assertEquals("AK806", event.get("transactionId"));
        assertEquals(2, event.get("count"));
        assertEquals(2, event.size());
    }
}
