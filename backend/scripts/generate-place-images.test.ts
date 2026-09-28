import sharp from 'sharp';
import { fitToBudget } from './generate-place-images';
import { PLACE_MAX_BYTES, PLACE_WIDTH } from './seed/placeImages';
import { PLACE_PROMPTS, PLACE_STYLE, placePrompt } from './places/prompts';

/**
 * THE GENERATOR, WITHOUT THE API.
 *
 * It is a hand-run script that writes committed files, so what CI can usefully
 * hold down is narrow and worth having: the prompts carry their constraints,
 * and the encoder actually meets the plate's budget for a picture it has never
 * seen.
 *
 * The API call itself is not exercised — a test that hits a paid image endpoint
 * on every push is a test that will be deleted within the month. The endpoint,
 * the model id and the response shape are named once in the script and were
 * checked against the published API when it was written; the size loop below is
 * the part that has a failure mode nobody would notice.
 */
describe('the place prompts', () => {
  it('has one per code, with no duplicates', () => {
    const codes = PLACE_PROMPTS.map((p) => p.code);
    expect(new Set(codes).size).toBe(codes.length);
  });

  it('appends the constraints to every one of them', () => {
    for (const place of PLACE_PROMPTS) {
      const prompt = placePrompt(place);
      expect(prompt.startsWith(place.scene)).toBe(true);
      expect(prompt).toContain(PLACE_STYLE);
    }
  });

  it('forbids brand marks, signage and identifiable faces', () => {
    // Not taste. A generated logo is a real company's mark on a picture it
    // never authorised, and a generated face is a person who did not consent to
    // being in a demo dataset.
    expect(PLACE_STYLE).toMatch(/no brand names or logos/i);
    expect(PLACE_STYLE).toMatch(/no shop signage/i);
    expect(PLACE_STYLE).toMatch(/no recognisable faces/i);
  });

  it('names a real South African place in every scene', () => {
    // The point of the picture is that it is somewhere, and that it changes
    // when the scope changes. A scene with no place in it would be a mood.
    for (const place of PLACE_PROMPTS) {
      expect(place.scene.length).toBeGreaterThan(80);
    }
    const scenes = PLACE_PROMPTS.map((p) => p.scene).join(' ');
    for (const town of ['Johannesburg', 'Pretoria', 'Cape Town', 'Durban', 'Gqeberha']) {
      expect(scenes).toContain(town);
    }
  });
});

describe('fitToBudget', () => {
  /**
   * A hostile picture: full-resolution noise, which JPEG cannot compress. If
   * the loop can get this under the cap it can get a photograph under it.
   */
  async function noise(width: number, height: number): Promise<Buffer> {
    const pixels = Buffer.alloc(width * height * 3);
    let a = 1;
    for (let i = 0; i < pixels.length; i += 1) {
      a = (a * 1103515245 + 12345) >>> 0;
      pixels[i] = (a >>> 16) & 0xff;
    }
    return sharp(pixels, { raw: { width, height, channels: 3 } }).jpeg().toBuffer();
  }

  it('resizes to the stored width and lands inside the budget', async () => {
    const { bytes } = await fitToBudget(await noise(1376, 768));
    expect(bytes.length).toBeLessThanOrEqual(PLACE_MAX_BYTES);
    const meta = await sharp(bytes).metadata();
    expect(meta.width).toBe(PLACE_WIDTH);
    expect(meta.format).toBe('jpeg');
  }, 30_000);

  it('spends quality rather than pixels, and says so in the number it returns', async () => {
    // The budget is met by walking the JPEG quality down, not by cropping: a
    // plate paints at 12% chroma under a #474747 ceiling, so the whole picture
    // lands in a near-neutral band where ringing has nowhere to show. Cropping
    // would instead take away the thing the picture is of.
    const easy = await sharp({
      create: { width: 1376, height: 768, channels: 3, background: '#888888' },
    })
      .jpeg()
      .toBuffer();
    const { quality } = await fitToBudget(easy);
    expect(quality).toBe(82);
  }, 30_000);

  it('refuses rather than writing something over the cap', async () => {
    await expect(fitToBudget(await noise(1376, 768), 1_000)).rejects.toThrow(/budget/);
  }, 30_000);
});
