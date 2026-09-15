import { createHash } from 'crypto';
import sharp from 'sharp';
import { reencodedCopy, shelfJpeg, toDataUrl } from '../../test-utils/shelfImage';
import {
  computePhotoHashes,
  decodeImageDataUrl,
  differenceHash,
  hammingDistance,
  isDegeneratePerceptualHash,
  MAX_NEAR_DUPLICATE_DISTANCE,
  perceptualHashBands,
  perceptualHashProbeKeys,
} from './photoHash';

/** #244 — the hashes upload stores so duplicate_photo never compares `url`. */
describe('photo hashes (#244)', () => {
  const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

  describe('computePhotoHashes', () => {
    it('hashes the DECODED bytes of a base64 image data URL, plus a 64-bit dHash and its bands', async () => {
      const jpeg = await shelfJpeg(1);
      const hashes = await computePhotoHashes(toDataUrl(jpeg));

      expect(hashes.contentHash).toBe(sha256(jpeg));
      expect(hashes.perceptualHash).toMatch(/^[0-9a-f]{16}$/);
      expect(hashes.perceptualHashBands).toEqual(perceptualHashBands(hashes.perceptualHash));
      expect(hashes.perceptualHashBands).toHaveLength(4);
    });

    it('gives the same content hash whatever the data URL subtype says', async () => {
      const jpeg = await shelfJpeg(1);
      const a = await computePhotoHashes(toDataUrl(jpeg, 'image/jpeg'));
      const b = await computePhotoHashes(toDataUrl(jpeg, 'image/png'));
      expect(a.contentHash).toBe(b.contentHash);
    });

    it('stores nothing for a payload that is not a base64 image data URL', async () => {
      const none = { contentHash: null, perceptualHash: null, perceptualHashBands: [] };
      expect(await computePhotoHashes('https://example.test/shelf.jpg')).toEqual(none);
      expect(await computePhotoHashes('data:text/plain;base64,aGVsbG8=')).toEqual(none);
      expect(await computePhotoHashes('data:image/jpeg;base64,')).toEqual(none);
      expect(decodeImageDataUrl('not a data url')).toBeNull();
    });

    it('keeps the content hash but no perceptual hash when the bytes do not decode', async () => {
      // 'aGVsbG8=' is "hello": a valid data URL whose payload is not an image.
      const hashes = await computePhotoHashes('data:image/jpeg;base64,aGVsbG8=');
      expect(hashes).toEqual({
        contentHash: sha256(Buffer.from('hello')),
        perceptualHash: null,
        perceptualHashBands: [],
      });
    });
  });

  describe('differenceHash', () => {
    it('stays within the near-duplicate threshold for a re-encoded, resized or PNG copy', async () => {
      const jpeg = await shelfJpeg(1);
      const original = await differenceHash(jpeg);
      const copies = [
        await reencodedCopy(jpeg),
        await sharp(jpeg).png().toBuffer(),
        await sharp(jpeg).jpeg({ quality: 40 }).toBuffer(),
      ];
      for (const copy of copies) {
        // 6 is the engine's default (DEFAULT_DUPLICATE_PHOTO_MAX_DISTANCE).
        expect(hammingDistance(original, await differenceHash(copy))).toBeLessThanOrEqual(6);
      }
      // The copy is not byte-identical, so only the perceptual hash can see it.
      expect(sha256(await reencodedCopy(jpeg))).not.toBe(sha256(jpeg));
    });

    it('puts unrelated frames far beyond anything the index can match', async () => {
      const original = await differenceHash(await shelfJpeg(1));
      for (const seed of [2, 3, 4, 5, 6, 7, 8]) {
        const other = await differenceHash(await shelfJpeg(seed));
        expect(hammingDistance(original, other)).toBeGreaterThan(3 * MAX_NEAR_DUPLICATE_DISTANCE);
      }
    });

    it('honours EXIF orientation, so a baked-in rotation hashes like the tagged original', async () => {
      const jpeg = await shelfJpeg(3);
      const tagged = await sharp(jpeg).withMetadata({ orientation: 6 }).jpeg().toBuffer();
      const baked = await sharp(tagged).rotate().jpeg().toBuffer();
      const taggedHash = await differenceHash(tagged);
      // A re-save that baked the rotation in is still a near-duplicate (the extra
      // JPEG generation costs a few bits)...
      expect(hammingDistance(taggedHash, await differenceHash(baked))).toBeLessThanOrEqual(6);
      // ...because the tag was applied: the same pixels read sideways are unrelated.
      expect(hammingDistance(taggedHash, await differenceHash(jpeg))).toBeGreaterThan(MAX_NEAR_DUPLICATE_DISTANCE);
    });

    it('refuses a decompression bomb rather than decoding it', async () => {
      const bomb = await sharp({
        create: { width: 9000, height: 9000, channels: 3, background: { r: 0, g: 0, b: 0 } },
      })
        .png()
        .toBuffer();
      await expect(differenceHash(bomb)).rejects.toThrow();
      const hashes = await computePhotoHashes(toDataUrl(bomb, 'image/png'));
      expect(hashes.contentHash).toBe(sha256(bomb));
      expect(hashes.perceptualHash).toBeNull();
    });
  });

  describe('degenerate frames', () => {
    it('gives a blank frame a hash, but no bands, so it is never a near-duplicate candidate', async () => {
      const blank = await sharp({
        create: { width: 400, height: 300, channels: 3, background: { r: 90, g: 90, b: 90 } },
      })
        .jpeg()
        .toBuffer();
      const hashes = await computePhotoHashes(toDataUrl(blank));
      expect(hashes.contentHash).toBe(sha256(blank));
      expect(hashes.perceptualHash).not.toBeNull();
      expect(isDegeneratePerceptualHash(hashes.perceptualHash!)).toBe(true);
      expect(hashes.perceptualHashBands).toEqual([]);
      expect(perceptualHashProbeKeys(hashes.perceptualHash, 6)).toEqual([]);
    });

    it('treats near-all-ones like near-all-zeros', () => {
      expect(isDegeneratePerceptualHash('ffffffffffffffff')).toBe(true);
      expect(isDegeneratePerceptualHash('0000000000000000')).toBe(true);
      expect(isDegeneratePerceptualHash('00ff00ff00ff00ff')).toBe(false);
    });
  });

  describe('hamming distance and the band index', () => {
    it('counts differing bits', () => {
      expect(hammingDistance('0000000000000000', 'ffffffffffffffff')).toBe(64);
      expect(hammingDistance('0000000000000000', '8000000000000001')).toBe(2);
      expect(hammingDistance('0123456789abcdef', '0123456789abcdef')).toBe(0);
    });

    it('tags each 16-bit band with its position, and stores nothing for a malformed hash', () => {
      expect(perceptualHashBands('0123456789abcdef')).toEqual([
        0x0123,
        (1 << 16) | 0x4567,
        (2 << 16) | 0x89ab,
        (3 << 16) | 0xcdef,
      ]);
      expect(perceptualHashBands(null)).toEqual([]);
      expect(perceptualHashBands('0123')).toEqual([]);
      expect(perceptualHashBands('0123456789ABCDEF')).toEqual([]);
      expect(perceptualHashBands('0123456789abcdeg')).toEqual([]);
    });

    it('probes the four stored bands within 3 bits, and each band plus its one-bit neighbours up to 7', () => {
      const hex = '0123456789abcdef';
      expect(perceptualHashProbeKeys(hex, 3)).toEqual(perceptualHashBands(hex));
      expect(perceptualHashProbeKeys(hex, 0)).toEqual(perceptualHashBands(hex));
      expect(new Set(perceptualHashProbeKeys(hex, 7)).size).toBe(68);
      expect(perceptualHashProbeKeys(hex, -1)).toEqual([]);
      expect(MAX_NEAR_DUPLICATE_DISTANCE).toBe(7);
    });

    it('finds every stored hash within the distance it was asked for, up to the ceiling', () => {
      // A property check of the pigeonhole argument in photoHash.ts: flip up to
      // 7 random bits, and the probe must share a key with the flipped hash's
      // stored bands.
      let state = 42;
      const random = (n: number) => {
        state = (state * 1103515245 + 12345) % 2147483648;
        return Math.floor((state / 2147483648) * n);
      };
      let checked = 0;
      while (checked < 400) {
        const value = BigInt.asUintN(64, (BigInt(random(2 ** 31)) << 33n) ^ (BigInt(random(2 ** 31)) << 2n) ^ BigInt(random(4)));
        const hex = value.toString(16).padStart(16, '0');
        if (isDegeneratePerceptualHash(hex)) {
          continue;
        }
        const distance = 1 + random(MAX_NEAR_DUPLICATE_DISTANCE);
        const bits = new Set<number>();
        while (bits.size < distance) {
          bits.add(random(64));
        }
        let flipped = value;
        for (const bit of bits) {
          flipped ^= 1n << BigInt(bit);
        }
        const flippedHex = flipped.toString(16).padStart(16, '0');
        if (isDegeneratePerceptualHash(flippedHex)) {
          continue;
        }
        expect(hammingDistance(hex, flippedHex)).toBe(distance);
        const stored = new Set(perceptualHashBands(flippedHex));
        const probe = perceptualHashProbeKeys(hex, distance);
        expect(probe.some((key) => stored.has(key))).toBe(true);
        checked += 1;
      }
    });
  });
});
