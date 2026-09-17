import { inflateRawSync } from 'zlib';

/**
 * Just enough ZIP reading to open Stats SA's time-series downloads.
 *
 * Those archives hold a handful of files, stored or deflated, with no
 * encryption and no ZIP64. Reading the central directory and inflating with
 * Node's own zlib covers that without a dependency. Anything else — a
 * multi-disk archive, an unknown compression method, a size past the bound —
 * is refused rather than half-read.
 */

export class ZipFormatError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ZipFormatError';
  }
}

export interface ZipEntry {
  name: string;
  data: Buffer;
}

const END_OF_CENTRAL_DIRECTORY = 0x06054b50;
const CENTRAL_FILE_HEADER = 0x02014b50;
const LOCAL_FILE_HEADER = 0x04034b50;
/** Uncompressed bound per entry: the largest real file is ~1.2 MB. */
export const MAX_ENTRY_BYTES = 32 * 1024 * 1024;

export function readZip(archive: Buffer, wanted: (name: string) => boolean = () => true): ZipEntry[] {
  // The end-of-central-directory record sits in the last 22 bytes plus an
  // optional comment of up to 65535 bytes.
  let eocd = -1;
  for (let i = archive.length - 22; i >= Math.max(0, archive.length - 22 - 65_535); i -= 1) {
    if (archive.readUInt32LE(i) === END_OF_CENTRAL_DIRECTORY) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw new ZipFormatError('Not a zip archive.');

  const count = archive.readUInt16LE(eocd + 10);
  let offset = archive.readUInt32LE(eocd + 16);
  const entries: ZipEntry[] = [];

  for (let n = 0; n < count; n += 1) {
    if (offset + 46 > archive.length || archive.readUInt32LE(offset) !== CENTRAL_FILE_HEADER) {
      throw new ZipFormatError('Corrupt zip central directory.');
    }
    const method = archive.readUInt16LE(offset + 10);
    const compressedSize = archive.readUInt32LE(offset + 20);
    const size = archive.readUInt32LE(offset + 24);
    const nameLength = archive.readUInt16LE(offset + 28);
    const extraLength = archive.readUInt16LE(offset + 30);
    const commentLength = archive.readUInt16LE(offset + 32);
    const localOffset = archive.readUInt32LE(offset + 42);
    const name = archive.toString('utf8', offset + 46, offset + 46 + nameLength);
    offset += 46 + nameLength + extraLength + commentLength;

    if (name.endsWith('/') || !wanted(name)) continue;
    if (size > MAX_ENTRY_BYTES) throw new ZipFormatError(`${name} is larger than expected.`);
    if (archive.readUInt32LE(localOffset) !== LOCAL_FILE_HEADER) {
      throw new ZipFormatError('Corrupt zip local header.');
    }
    const dataStart =
      localOffset + 30 + archive.readUInt16LE(localOffset + 26) + archive.readUInt16LE(localOffset + 28);
    const raw = archive.subarray(dataStart, dataStart + compressedSize);

    let data: Buffer;
    if (method === 0) data = Buffer.from(raw);
    else if (method === 8) data = inflateRawSync(raw, { maxOutputLength: MAX_ENTRY_BYTES });
    else throw new ZipFormatError(`${name} uses an unsupported compression method (${method}).`);
    if (data.length !== size) throw new ZipFormatError(`${name} did not inflate to its stated size.`);
    entries.push({ name, data });
  }
  return entries;
}
