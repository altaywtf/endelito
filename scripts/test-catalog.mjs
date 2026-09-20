import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const { sources, aliases } = JSON.parse(readFileSync(new URL("../app/Resources/sources.json", import.meta.url), "utf8"));
const ids = new Set(sources.map(({ id }) => id));
assert.equal(ids.size, sources.length, "source IDs must be unique");
assert.ok(ids.has("focus"), "default source must exist");
for (const { id, name, modality } of sources) {
  assert.match(id, /^[a-z0-9-]+$/);
  assert.ok(name.length > 0);
  assert.ok(["focus", "relax", "sleep"].includes(modality));
}
for (const [alias, target] of Object.entries(aliases)) {
  assert.ok(ids.has(target), `${alias} points to unknown source ${target}`);
}
console.log("catalog: ok");
