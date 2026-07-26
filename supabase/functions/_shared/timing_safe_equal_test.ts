import { assertEquals } from "https://deno.land/std@0.201.0/testing/asserts.ts";
import { timingSafeEqual } from "./timing_safe_equal.ts";

Deno.test("timingSafeEqual: equal strings match", () => {
  assertEquals(timingSafeEqual("topsecret", "topsecret"), true);
});

Deno.test("timingSafeEqual: different strings of same length don't match", () => {
  assertEquals(timingSafeEqual("topsecret", "topsecreu"), false);
});

Deno.test("timingSafeEqual: different lengths don't match", () => {
  assertEquals(timingSafeEqual("short", "muchlongersecret"), false);
});

Deno.test("timingSafeEqual: empty strings match", () => {
  assertEquals(timingSafeEqual("", ""), true);
});
