var openp41geConfig = (function(exports) {
  "use strict";
  const CONFIG_TYPES = ["object", "array", "string", "number", "integer", "boolean", "null"];
  function isPlainObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
  }
  function clone(value) {
    return value === void 0 ? value : JSON.parse(JSON.stringify(value));
  }
  function at(path, key) {
    return path ? `${path}.${key}` : key;
  }
  function prefix(path, message) {
    return path ? `${path}: ${message}` : message;
  }
  function validateConfigSchema(schema) {
    if (!isPlainObject(schema) || schema.type !== "object") {
      throw new Error('config schema: the root must be an object schema ({ type: "object" })');
    }
    checkSchema(schema, "");
    return schema;
  }
  function checkSchema(schema, path) {
    const fail = (message) => {
      throw new Error(`config schema: ${prefix(path, message)}`);
    };
    if (schema.type !== void 0) {
      const types = Array.isArray(schema.type) ? schema.type : [schema.type];
      const unknown = types.find((t) => !CONFIG_TYPES.includes(t));
      if (unknown !== void 0 || types.length === 0) {
        fail(`unknown type ${JSON.stringify(unknown)}`);
      }
    }
    if (schema.properties !== void 0) {
      if (!isPlainObject(schema.properties)) fail("properties must be an object");
      for (const [key, sub] of Object.entries(schema.properties)) {
        if (!isPlainObject(sub)) fail(`${at(path, key)} must be a schema`);
        const keysOf = sub["x-keysOf"];
        if (keysOf !== void 0 && (typeof keysOf !== "string" || !(keysOf in schema.properties))) {
          fail(`${at(path, key)}: x-keysOf must name a sibling property`);
        }
        checkSchema(sub, at(path, key));
      }
    }
    if (schema.items !== void 0) {
      if (!isPlainObject(schema.items)) fail("items must be a schema");
      checkSchema(schema.items, `${path}[]`);
    }
    if (isPlainObject(schema.additionalProperties)) {
      checkSchema(schema.additionalProperties, at(path, "*"));
    }
    if (schema.required !== void 0 && !(Array.isArray(schema.required) && schema.required.every((r) => typeof r === "string"))) {
      fail("required must be a list of names");
    }
    if (schema.enum !== void 0 && !Array.isArray(schema.enum)) fail("enum must be a list");
    if (schema.default !== void 0) {
      const errors = configErrors(schema, schema.default);
      if (errors.length > 0) fail(`default: ${errors[0]}`);
    }
  }
  function configDefaults(schema) {
    const out = {};
    for (const [key, sub] of Object.entries(schema.properties ?? {})) {
      if (sub.default !== void 0) {
        out[key] = clone(sub.default);
      } else if (sub.properties) {
        const nested = configDefaults(sub);
        if (Object.keys(nested).length > 0) out[key] = nested;
      }
    }
    return out;
  }
  function typeMatches(type, value) {
    switch (type) {
      case "object":
        return isPlainObject(value);
      case "array":
        return Array.isArray(value);
      case "integer":
        return typeof value === "number" && Number.isInteger(value);
      case "null":
        return value === null;
      default:
        return typeof value === type;
    }
  }
  function configErrors(schema, value, path = "") {
    if (schema.type) {
      const types = Array.isArray(schema.type) ? schema.type : [schema.type];
      if (!types.some((t) => typeMatches(t, value))) {
        return [prefix(path, `expected ${types.join(" or ")}`)];
      }
    }
    const errors = [];
    if (schema.enum && !schema.enum.some((e) => JSON.stringify(e) === JSON.stringify(value))) {
      errors.push(
        prefix(path, `must be one of ${schema.enum.map((e) => JSON.stringify(e)).join(", ")}`)
      );
    }
    if (typeof value === "number") {
      if (schema.minimum !== void 0 && value < schema.minimum) {
        errors.push(prefix(path, `must be at least ${schema.minimum}`));
      }
      if (schema.maximum !== void 0 && value > schema.maximum) {
        errors.push(prefix(path, `must be at most ${schema.maximum}`));
      }
    }
    if (Array.isArray(value) && schema.items) {
      value.forEach((item, i) => errors.push(...configErrors(schema.items, item, `${path}[${i}]`)));
    }
    if (isPlainObject(value)) {
      const properties = schema.properties ?? {};
      for (const name of schema.required ?? []) {
        if (value[name] === void 0) errors.push(`${at(path, name)}: is required`);
      }
      for (const [key, item] of Object.entries(value)) {
        const sub = properties[key];
        if (sub) {
          errors.push(...configErrors(sub, item, at(path, key)));
        } else if (schema.additionalProperties === false) {
          errors.push(`${at(path, key)}: is not allowed`);
        } else if (isPlainObject(schema.additionalProperties)) {
          errors.push(...configErrors(schema.additionalProperties, item, at(path, key)));
        }
      }
      for (const [name, sub] of Object.entries(properties)) {
        const map = sub["x-keysOf"] === void 0 ? void 0 : value[sub["x-keysOf"]];
        const v = value[name];
        if (typeof v === "string" && isPlainObject(map) && !(v in map)) {
          const keys = Object.keys(map).map((k) => JSON.stringify(k));
          errors.push(
            `${at(path, name)}: must be one of the keys of ${sub["x-keysOf"]} (${keys.join(", ")})`
          );
        }
      }
    }
    return errors;
  }
  function mergeConfig(defaults, overrides) {
    const out = clone(defaults);
    for (const [key, value] of Object.entries(overrides)) {
      if (value === void 0) continue;
      out[key] = isPlainObject(value) && isPlainObject(out[key]) ? mergeConfig(out[key], value) : clone(value);
    }
    return out;
  }
  exports.configDefaults = configDefaults;
  exports.configErrors = configErrors;
  exports.mergeConfig = mergeConfig;
  exports.validateConfigSchema = validateConfigSchema;
  Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
  return exports;
})({});
