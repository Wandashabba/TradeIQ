import { z } from 'zod';
import { toGeminiSchema, UnsupportedSchemaError } from './geminiSchema';

/** Zod schema → the JSON Schema the adapter would hand the converter. */
function json(schema: z.ZodType): unknown {
  return z.toJSONSchema(schema, { io: 'input' });
}

describe('toGeminiSchema', () => {
  it('uppercases every type onto Gemini\'s Type enum', () => {
    // Gemini's `type` is an enum, not a JSON Schema string. Lowercase is a 400.
    const out = toGeminiSchema(
      json(
        z.object({
          s: z.string(),
          n: z.number(),
          i: z.number().int(),
          b: z.boolean(),
          a: z.array(z.string()),
          o: z.object({ inner: z.string() }),
        }),
      ),
    );

    expect(out.type).toBe('OBJECT');
    expect(out.properties?.s.type).toBe('STRING');
    expect(out.properties?.n.type).toBe('NUMBER');
    expect(out.properties?.i.type).toBe('INTEGER');
    expect(out.properties?.b.type).toBe('BOOLEAN');
    expect(out.properties?.a.type).toBe('ARRAY');
    expect(out.properties?.o.type).toBe('OBJECT');
  });

  it('strips $schema, which Gemini rejects as an unknown key', () => {
    const out = toGeminiSchema(json(z.object({ a: z.string() })));
    expect(JSON.stringify(out)).not.toContain('$schema');
  });

  it('renders size bounds as strings', () => {
    // maxItems/maxLength are `string` on Gemini's Schema and `number` in JSON
    // Schema. Passing the number through is a 400 with an unhelpful message.
    const out = toGeminiSchema(
      json(z.object({ tags: z.array(z.string()).min(1).max(5), name: z.string().max(80) })),
    );

    expect(out.properties?.tags.minItems).toBe('1');
    expect(out.properties?.tags.maxItems).toBe('5');
    expect(out.properties?.name.maxLength).toBe('80');
  });

  it('keeps numeric bounds numeric', () => {
    // minimum/maximum are the exception — those really are numbers on both.
    const out = toGeminiSchema(json(z.object({ n: z.number().min(1).max(10) })));
    expect(out.properties?.n.minimum).toBe(1);
    expect(out.properties?.n.maximum).toBe(10);
  });

  it('carries descriptions through, because they steer tool arguments', () => {
    const out = toGeminiSchema(
      json(z.object({ agentId: z.string().describe('The id of the field agent') })),
    );
    expect(out.properties?.agentId.description).toBe('The id of the field agent');
  });

  it('preserves required', () => {
    const out = toGeminiSchema(json(z.object({ a: z.string(), b: z.string().optional() })));
    expect(out.required).toEqual(['a']);
  });

  it('collapses a nullable union onto the nullable flag', () => {
    // Zod emits `anyOf: [{string},{null}]`. Gemini has no union type — it has a
    // boolean. Dropping this loses the constraint SILENTLY, because Gemini
    // accepts the truncated schema without complaint.
    const out = toGeminiSchema(json(z.object({ note: z.string().nullable() })));

    expect(out.properties?.note.type).toBe('STRING');
    expect(out.properties?.note.nullable).toBe(true);
    expect(out.properties?.note.anyOf).toBeUndefined();
  });

  it('handles the type-array spelling of nullable too', () => {
    const out = toGeminiSchema({ type: ['string', 'null'] });
    expect(out.type).toBe('STRING');
    expect(out.nullable).toBe(true);
  });

  it('turns a literal into a single-entry enum', () => {
    // Gemini has no `const`. Dropping it tells the model the field is a free
    // string — another silent widening.
    const out = toGeminiSchema(json(z.object({ kind: z.literal('mtd') })));
    expect(out.properties?.kind.enum).toEqual(['mtd']);
  });

  it('passes string enums through', () => {
    const out = toGeminiSchema(json(z.object({ period: z.enum(['today', 'mtd', 'ytd']) })));
    expect(out.properties?.period.enum).toEqual(['today', 'mtd', 'ytd']);
    expect(out.properties?.period.type).toBe('STRING');
  });

  it('orders properties deterministically, because the prefix is cached', () => {
    // Two structurally identical schemas must serialise identically or the
    // cache misses — a cost regression with no functional symptom.
    const a = toGeminiSchema(json(z.object({ one: z.string(), two: z.string() })));
    const b = toGeminiSchema(json(z.object({ one: z.string(), two: z.string() })));

    expect(JSON.stringify(a)).toBe(JSON.stringify(b));
    expect(a.propertyOrdering).toEqual(['one', 'two']);
  });

  it('recurses into arrays of objects', () => {
    const out = toGeminiSchema(json(z.object({ rows: z.array(z.object({ id: z.string() })) })));
    expect(out.properties?.rows.items?.properties?.id.type).toBe('STRING');
  });

  describe('refuses what it cannot express, rather than dropping it', () => {
    it('throws on a numeric enum', () => {
      // Gemini's enum is string[]. Silently coercing hands the model quoted
      // numbers it will send back as strings, failing at the Zod boundary.
      expect(() => toGeminiSchema({ enum: [1, 2, 3] })).toThrow(UnsupportedSchemaError);
    });

    it('throws on oneOf and allOf', () => {
      expect(() => toGeminiSchema({ oneOf: [{ type: 'string' }] })).toThrow(UnsupportedSchemaError);
      expect(() => toGeminiSchema({ allOf: [{ type: 'string' }] })).toThrow(UnsupportedSchemaError);
    });

    it('throws on $ref', () => {
      expect(() => toGeminiSchema({ $ref: '#/$defs/Node' })).toThrow(UnsupportedSchemaError);
    });

    it('throws on an unknown type', () => {
      expect(() => toGeminiSchema({ type: 'tuple' })).toThrow(UnsupportedSchemaError);
    });

    it('names the path so the offending field is findable', () => {
      // A tool schema can be deep. "Unsupported schema" alone is not actionable.
      expect(() =>
        toGeminiSchema({ type: 'object', properties: { filters: { oneOf: [{ type: 'string' }] } } }),
      ).toThrow(/properties\/filters/);
    });
  });

  it('rejects a non-object schema', () => {
    expect(() => toGeminiSchema('nope')).toThrow(UnsupportedSchemaError);
  });
});
