import { Type, type Schema } from '@google/genai';

/**
 * JSON Schema (as Zod emits it) → Gemini's `Schema`.
 *
 * Split out of `gemini.ts` because it is **pure** — no key, no network, no SDK
 * client — and the design rule in the plan is that pure files are exhaustively
 * unit-testable with plain Jest. The adapter around it is neither.
 *
 * This conversion is not cosmetic. Gemini's `Schema` looks like JSON Schema and
 * is not, and every difference below fails in a way that is easy to miss:
 *
 * | JSON Schema (Zod)             | Gemini `Schema`         | If you skip it |
 * |-------------------------------|-------------------------|----------------|
 * | `"type": "string"`            | `type: Type.STRING`     | 400 INVALID_ARGUMENT |
 * | `"type": "integer"`           | `type: Type.INTEGER`    | 400 |
 * | `"maxItems": 3` (number)      | `maxItems: "3"` (string)| 400 |
 * | `"$schema": …`                | *no such field*         | 400 on an unknown key |
 * | `"additionalProperties"`      | *no such field*         | 400 |
 * | `["string", "null"]` / `anyOf`| `nullable: true`        | constraint silently lost |
 * | `"const": "x"`                | `enum: ["x"]`           | constraint silently lost |
 *
 * The last two are the dangerous ones, because they do not error — they widen
 * what the model believes it may send. The tool's Zod schema still rejects the
 * bad value at `run()` time, so nothing unsafe gets through, but the failure
 * surfaces as a confusing mid-turn tool error rather than as a constraint the
 * model was told about up front.
 *
 * **Unsupported constructs throw rather than being dropped.** A silently
 * discarded constraint is a schema that lies to the model. Throwing turns it
 * into a loud failure that `tools.schema.test.ts` catches for every registered
 * tool before it can reach a request.
 */

/** The subset of JSON Schema keys Zod emits that map onto a Gemini field. */
interface JsonSchemaNode {
  type?: string | string[];
  description?: string;
  title?: string;
  format?: string;
  enum?: unknown[];
  const?: unknown;
  default?: unknown;
  pattern?: string;
  properties?: Record<string, unknown>;
  required?: string[];
  items?: unknown;
  anyOf?: unknown[];
  oneOf?: unknown[];
  allOf?: unknown[];
  minimum?: number;
  maximum?: number;
  minLength?: number;
  maxLength?: number;
  minItems?: number;
  maxItems?: number;
  minProperties?: number;
  maxProperties?: number;
  $ref?: string;
  $defs?: unknown;
}

const TYPE_BY_JSON_NAME: Readonly<Record<string, Type>> = {
  string: Type.STRING,
  number: Type.NUMBER,
  integer: Type.INTEGER,
  boolean: Type.BOOLEAN,
  array: Type.ARRAY,
  object: Type.OBJECT,
};

export class UnsupportedSchemaError extends Error {
  constructor(message: string, readonly path: string) {
    super(`${message} (at ${path || '<root>'})`);
    this.name = 'UnsupportedSchemaError';
  }
}

/**
 * Gemini expresses every size bound as a **string**, not a number, and rejects
 * the request outright if given a number. Nothing about the field name hints at
 * it, which is why it lives in one place rather than at six call sites.
 */
function sizeBound(value: number | undefined): string | undefined {
  return value === undefined ? undefined : String(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Collapse Zod's nullable encoding onto Gemini's `nullable` flag.
 *
 * Zod emits `z.string().nullable()` as `anyOf: [{type:'string'},{type:'null'}]`
 * and, in some positions, as `type: ['string','null']`. Gemini has no union
 * type; it has a boolean. Both encodings therefore have to be recognised here
 * or the nullability is lost — and because Gemini would accept the truncated
 * schema without complaint, losing it is silent.
 *
 * A genuine union of two non-null types is a different thing and is left to
 * `anyOf`, which Gemini does support.
 */
function splitNullable(node: JsonSchemaNode): { node: JsonSchemaNode; nullable: boolean } {
  if (Array.isArray(node.type)) {
    const nonNull = node.type.filter((t) => t !== 'null');
    if (nonNull.length !== node.type.length) {
      return { node: { ...node, type: nonNull[0] }, nullable: true };
    }
    return { node: { ...node, type: nonNull[0] }, nullable: false };
  }

  if (Array.isArray(node.anyOf)) {
    const branches = node.anyOf.filter(isRecord);
    const nulls = branches.filter((b) => b.type === 'null');
    const others = branches.filter((b) => b.type !== 'null');
    if (nulls.length > 0 && others.length === 1) {
      return { node: { ...others[0], description: node.description } as JsonSchemaNode, nullable: true };
    }
    if (nulls.length > 0) {
      return { node: { ...node, anyOf: others }, nullable: true };
    }
  }

  return { node, nullable: false };
}

function convert(raw: unknown, path: string): Schema {
  if (!isRecord(raw)) {
    throw new UnsupportedSchemaError('Expected a schema object', path);
  }

  const { node, nullable } = splitNullable(raw as JsonSchemaNode);

  // Zod inlines reused sub-schemas by default, so `$ref` should not appear.
  // "Should not" is not "cannot": a future schema built with a registry, or a
  // recursive type, would emit one — and Gemini cannot express it at all.
  if (node.$ref !== undefined) {
    throw new UnsupportedSchemaError(
      '$ref is not expressible in a Gemini schema. Inline the sub-schema, or ' +
        'flatten the tool arguments — a recursive tool argument is a design smell anyway',
      path,
    );
  }

  const out: Schema = {};

  if (node.description !== undefined) out.description = node.description;
  if (node.title !== undefined) out.title = node.title;
  if (node.format !== undefined) out.format = node.format;
  if (node.pattern !== undefined) out.pattern = node.pattern;
  if (node.default !== undefined) out.default = node.default;
  if (nullable) out.nullable = true;

  if (node.minimum !== undefined) out.minimum = node.minimum;
  if (node.maximum !== undefined) out.maximum = node.maximum;
  out.minLength = sizeBound(node.minLength);
  out.maxLength = sizeBound(node.maxLength);
  out.minItems = sizeBound(node.minItems);
  out.maxItems = sizeBound(node.maxItems);
  out.minProperties = sizeBound(node.minProperties);
  out.maxProperties = sizeBound(node.maxProperties);

  // A single-value `const` is a one-entry enum. Gemini has no `const`, so
  // dropping it would tell the model the field is a free string.
  if (node.const !== undefined) {
    out.enum = [String(node.const)];
    out.type = Type.STRING;
  } else if (node.enum !== undefined) {
    // Gemini's `enum` is `string[]`. Numeric enums have to be declared as their
    // underlying type instead of enumerated, or the model is handed quoted
    // numbers it will then send back as strings.
    if (node.enum.every((v) => typeof v === 'string')) {
      out.enum = node.enum as string[];
      out.type = Type.STRING;
    } else {
      throw new UnsupportedSchemaError(
        "Gemini's enum accepts strings only. Model the field as a string enum, " +
          'or as a plain number with minimum/maximum bounds',
        path,
      );
    }
  }

  if (Array.isArray(node.anyOf)) {
    out.anyOf = node.anyOf.map((branch, i) => convert(branch, `${path}/anyOf/${i}`));
  }

  // `oneOf` and `allOf` have no Gemini equivalent. `oneOf` is *almost* `anyOf`
  // and mapping it across would quietly relax exclusivity, so it is refused.
  if (node.oneOf !== undefined || node.allOf !== undefined) {
    throw new UnsupportedSchemaError(
      'oneOf/allOf have no Gemini equivalent. Use a discriminated union of ' +
        'string-tagged objects, or split the tool in two',
      path,
    );
  }

  if (typeof node.type === 'string') {
    const mapped = TYPE_BY_JSON_NAME[node.type];
    if (mapped === undefined) {
      throw new UnsupportedSchemaError(`Unknown JSON Schema type "${node.type}"`, path);
    }
    out.type = mapped;
  }

  if (node.properties !== undefined) {
    const properties: Record<string, Schema> = {};
    for (const [key, value] of Object.entries(node.properties)) {
      properties[key] = convert(value, `${path}/properties/${key}`);
    }
    out.properties = properties;
    // Ordering is deterministic because the prompt prefix is cached and a
    // reordered tool declaration is a different prefix — a silent cost
    // regression with no functional symptom. `Object.entries` preserves
    // insertion order for string keys, which is the Zod declaration order.
    out.propertyOrdering = Object.keys(node.properties);
  }

  if (node.required !== undefined) out.required = node.required;
  if (node.items !== undefined) out.items = convert(node.items, `${path}/items`);

  // Strip the undefineds so two structurally identical schemas serialise
  // identically. The cache prefix is a byte comparison.
  for (const key of Object.keys(out) as (keyof Schema)[]) {
    if (out[key] === undefined) delete out[key];
  }

  return out;
}

/**
 * Convert a Zod-emitted JSON Schema into a Gemini function-declaration schema.
 *
 * Throws {@link UnsupportedSchemaError} rather than emitting a schema that
 * understates the real constraints.
 */
export function toGeminiSchema(jsonSchema: unknown): Schema {
  if (!isRecord(jsonSchema)) {
    throw new UnsupportedSchemaError('Expected a schema object', '');
  }
  // `$schema` and `$defs` are metadata Gemini rejects as unknown keys. They are
  // dropped rather than refused because they carry no constraint.
  const { $schema: _schema, $defs: _defs, ...rest } = jsonSchema as JsonSchemaNode &
    Record<string, unknown>;
  void _schema;
  void _defs;
  return convert(rest, '');
}
