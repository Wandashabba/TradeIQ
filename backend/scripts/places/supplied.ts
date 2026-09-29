/**
 * THE PICTURES THE OWNER SUPPLIED, ONE ENTRY PER TERRITORY.
 *
 * `prompts.ts` is the catalogue of scenes a model was asked for. This is the
 * catalogue of photographs that arrived instead, for **twelve of the thirteen
 * territories**. North West and the whole-footprint view keep their generated
 * images, and the two catalogues sit side by side rather than one replacing
 * the other: `place_images.source` is a column precisely so both can be true
 * at once.
 *
 * ## North West is deliberately not here
 *
 * A `North West.jpg` was supplied with the second batch and is **not** in this
 * list. It is a photograph of Seattle — the Space Needle with Mount Rainier
 * behind it. North West province is Rustenburg, Mahikeng and the
 * Magaliesberg, and a Pacific Northwest skyline standing in for it would be
 * wrong to every South African who opens the app. `NW` stays on its generated
 * image, which is at least of somewhere the territory could be, until a
 * replacement arrives. Leaving a territory generated is a state this system
 * already supports; putting the wrong continent on the plate is not.
 *
 * ## What is different about a supplied image, and what is not
 *
 * **Different:** it is a photograph, so the plate says *"A photograph of the
 * area"* rather than *"An illustration of the area"*. There is no prompt and
 * no model to record. And the generator's constraints — no readable signage,
 * no brand marks, no identifiable faces — **do not apply**, because nobody
 * generated it. See [SUPPLIED_RIGHTS].
 *
 * **Not different:** it is still not evidence. It goes to `place_images`, a
 * table with no `visitId`, no GPS tag and no capture time, and the sentence
 * the plate speaks still ends *"not from a visit"*. A real photograph of
 * Bloemfontein is a picture of a place, not a reading of a shelf in it, and
 * that is the whole boundary this feature is built inside.
 *
 * Bring them in with `cd backend && npm run import-place-images`.
 */

export interface SuppliedPlace {
  /** `Territory.code` in the seed catalogue. */
  readonly code: string;
  /** What a manager would call it on screen. */
  readonly label: string;
  /** The owner's original, relative to `assets/places`. */
  readonly originalFile: string;
  /** What the photograph is of. */
  readonly description: string;
  /**
   * Anything a reviewer has to know before looking at it on the plate.
   * Empty for a picture with nothing to declare.
   */
  readonly note?: string;
}

/**
 * THE RIGHTS, AND THE CONSTRAINTS THAT DO NOT APPLY.
 *
 * Written into the manifest by the importer so it travels with the assets
 * rather than living in one person's memory. Two separate statements:
 *
 * 1. These are the **owner's** images to license. Nothing in this repository
 *    acquired them, cleared them or can vouch for them; the generated set is
 *    ours because a script made it, and this set is not.
 * 2. The no-logos / no-signage / no-faces constraints that every line of
 *    `prompts.ts` carries are constraints on a **generator**, and a generator
 *    made none of these. `GP` carries lit brand signage across the
 *    Johannesburg skyline and `GP-TSH` carries a statue of a named person.
 *    Those are the owner's call on the owner's pictures — recorded here so
 *    nobody later reads them as a defect the prompt constraints failed to
 *    catch, and so nobody later "fixes" them.
 */
export const SUPPLIED_RIGHTS =
  'Supplied place images are the owner’s to license. This repository did not ' +
  'acquire or clear them and makes no claim to them; anyone reusing this ' +
  'dataset needs the owner’s permission, which is not the case for the ' +
  'generated set. The generator’s constraints in scripts/places/prompts.ts — ' +
  'no readable signage, no brand marks, no identifiable faces — are ' +
  'constraints on a model and DO NOT apply to these: GP carries lit brand ' +
  'signage across the Johannesburg skyline and GP-TSH carries the Mandela ' +
  'statue at the Union Buildings. That is the owner’s call on the owner’s ' +
  'photographs, written down rather than assumed, and not a defect.';

/**
 * The twelve the owner has supplied. Ordered as the manifest orders them.
 *
 * `EC-NMB` and `EC-BCM` are flagged: they are not plain photographs but map
 * composites — a pale territory outline with printed place names laid over a
 * photograph. See their notes, and §9g of `docs/design/torchlight-aisle.md`.
 */
export const SUPPLIED_PLACES: readonly SuppliedPlace[] = [
  {
    code: 'EC-BCM',
    label: 'Eastern Cape – Buffalo City',
    originalFile: 'supplied/EC-BCM-original.png',
    description:
      'The East London city hall in morning light, with a pale outline of the ' +
      'Buffalo City metro and its towns laid over it.',
    note:
      'A MAP COMPOSITE, NOT A PLAIN PHOTOGRAPH. The outline is the brightest ' +
      'thing in the frame and the printed names (Bisho, Mdantsane, East London) ' +
      'sit across the middle of it. Under the plate’s 12% chroma and #474747 ' +
      'ceiling the outline flattens to a mid-grey field and the names to darker ' +
      'grey marks inside it, directly behind the hero figure. Rendered and ' +
      'flagged for the owner rather than cropped: the map may well be the point.',
  },
  {
    code: 'EC-NMB',
    label: 'Eastern Cape – Nelson Mandela Bay',
    originalFile: 'supplied/EC-NMB-original.png',
    description:
      'The Gqeberha seafront at sunset, with a pale outline of the Nelson ' +
      'Mandela Bay metro and its towns laid over it.',
    note:
      'A MAP COMPOSITE, NOT A PLAIN PHOTOGRAPH — the same treatment as EC-BCM, ' +
      'and the same flag. The outline covers most of the right two-thirds of ' +
      'the frame and the names run down the middle of it.',
  },
  {
    code: 'FS',
    label: 'Free State',
    originalFile: 'supplied/FS-original.jpg',
    description:
      'Bloemfontein at dusk from the hill: the CBD strung out along a lit main ' +
      'road under a heavy violet sky.',
    note:
      'A small original at 612×459, so it is enlarged to reach the stored ' +
      '1024×572. Under the plate’s tone that costs nothing visible; a larger ' +
      'original would still be better if the owner has one.',
  },
  {
    code: 'GP',
    label: 'Gauteng',
    originalFile: 'supplied/GP-original.jpg',
    description:
      'The Nelson Mandela Bridge lit at night with the Johannesburg CBD behind ' +
      'it, from the Braamfontein side.',
    note:
      'Carries lit brand signage on the skyline and an illuminated billboard. ' +
      'Not a defect — see SUPPLIED_RIGHTS.',
  },
  {
    code: 'GP-EKU',
    label: 'Gauteng East (Ekurhuleni)',
    originalFile: 'supplied/GP-EKU-original.jpg',
    description:
      'An aerial of an East Rand town centre on a clear winter morning, the ' +
      'main street running away into the haze.',
  },
  {
    code: 'GP-TSH',
    label: 'Gauteng North (Tshwane)',
    originalFile: 'supplied/GP-TSH-original.jpg',
    description:
      'The Union Buildings terraces in Pretoria under a bright sky, with the ' +
      'Mandela statue on the lawn in front of them.',
    note:
      'Carries a statue of a named person, and one of the brightest skies in ' +
      'the set. Neither is a defect — see SUPPLIED_RIGHTS.',
  },
  {
    code: 'KZN',
    label: 'KwaZulu-Natal',
    originalFile: 'supplied/KZN-original.jpg',
    description:
      'The Umhlanga lighthouse at sunrise, the Indian Ocean breaking below it ' +
      'and a lit cloud bank filling most of the frame.',
    note:
      'One of the two brightest skies in the set. The plate’s luminance ceiling ' +
      'is what keeps it from washing out the ink over it; see the contrast ' +
      'figures in §9g of docs/design/torchlight-aisle.md.',
  },
  {
    code: 'KZN-PMB',
    label: 'KwaZulu-Natal Midlands',
    originalFile: 'supplied/KZN-PMB-original.jpg',
    description:
      'Pietermaritzburg city centre from above: the city hall clock tower, the ' +
      'main street and the Midlands hills behind it.',
  },
  {
    code: 'LP',
    label: 'Limpopo',
    originalFile: 'supplied/LP-original.jpg',
    description:
      'A civic park in the Limpopo capital: a fountain on the lake, a clock ' +
      'tower and the town centre behind the trees under a hard blue sky.',
  },
  {
    code: 'MP',
    label: 'Mpumalanga',
    originalFile: 'supplied/MP-original.webp',
    description:
      'The Blyde River Canyon from the viewpoint above the Three Rondavels, ' +
      'the dam below and cloud sitting on the escarpment.',
    note:
      'The only WebP original. It goes through the same importer as the rest — ' +
      'sharp decodes it, the same centre crop and the same quality walk apply — ' +
      'and the committed asset is a JPEG at the same size as every other one. ' +
      'The input format is not a property anything downstream can see.',
  },
  {
    code: 'WC',
    label: 'Western Cape',
    originalFile: 'supplied/WC-original.jpg',
    description:
      'Clifton from above at golden hour, the Twelve Apostles under the ' +
      'tablecloth cloud and the Atlantic breaking on the rocks below.',
    note:
      'The smallest original in the set at 620×388, so it is enlarged to reach ' +
      'the stored 1024×572, and one of the two brightest. A larger original ' +
      'would still be better if the owner has one.',
  },
  {
    code: 'WC-WIN',
    label: 'Western Cape Winelands',
    originalFile: 'supplied/WC-WIN-original.jpg',
    description:
      'Vineyard rows running away to a farmstead at sunset, with the sun ' +
      'breaking through a heavy cloud bank over the hills.',
  },
];
