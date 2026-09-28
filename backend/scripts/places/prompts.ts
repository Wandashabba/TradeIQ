/**
 * THE PLACE THE MANAGER IS LOOKING AT, ONE PROMPT PER TERRITORY.
 *
 * The Floor's plate used to carry a seeded "shelf photo" — four rows of
 * randomly coloured blocks from a PRNG. It read as noise, and worse, it read
 * as *evidence*: a picture of a shelf above a list of shelf decisions is a
 * picture a manager can act on. It was neither.
 *
 * So the plate now carries a picture of the **place in scope** — Gauteng North,
 * the Winelands, Nelson Mandela Bay — and it changes when the territory filter
 * changes. A townscape is plainly context rather than a reading: nobody
 * mistakes a street at sunrise for a stock count.
 *
 * ## The boundary these prompts are written inside
 *
 * Every image here is **generated**, and generated images are seed data. They
 * are fixtures, like every other seeded row, and the only reason they exist is
 * so a demo dataset shows somewhere recognisable instead of coloured noise.
 *
 * * They are written to `place_images`, a table of their own, with
 *   `source: 'generated'` — never to `photos`, which is where visit evidence,
 *   the review strip and pin-dispute storefronts live.
 * * They are **never** the fallback for a missing real photograph. That path
 *   keeps its drawing and its sentence: an invented shelf where a real one is
 *   missing is fabricated evidence.
 *
 * ## The constraints in every prompt, and why
 *
 * * **No brand marks, no readable shopfront signage.** A generated logo is a
 *   real company's mark on a picture that company never authorised.
 * * **No identifiable faces.** People at a distance, backs turned, or none.
 * * **Documentary, not stock.** The reference is a photograph somebody took
 *   on a working morning, not a composition sold by the thousand.
 * * **Varied light.** Thirteen territories under one golden hour would be a
 *   mood board. The real point of the picture is that it changes.
 *
 * Regenerating: see `backend/scripts/generate-place-images.ts`.
 */

export interface PlacePrompt {
  /** `Territory.code` in the seed catalogue, or `ALL` for the whole footprint. */
  readonly code: string;
  /** What a manager would call it on screen. */
  readonly label: string;
  /** The scene. */
  readonly scene: string;
}

/**
 * The rules every scene is generated under, appended to each prompt.
 *
 * One string rather than thirteen copies: a constraint that is retyped per
 * prompt is a constraint that goes missing from one of them.
 */
export const PLACE_STYLE =
  'Documentary photograph, shot on 35mm at eye level, natural available light, ' +
  'deep depth of field, no filter, no vignette. ' +
  'Absolutely no readable text, no shop signage, no lettering, no numbers, ' +
  'and no brand names or logos of any kind on any surface, vehicle or awning. ' +
  'No recognisable faces: any people are distant, small in frame, or turned away. ' +
  'Not a stock photograph, not a postcard, not an advertisement.';

/**
 * One scene per seeded territory, plus the all-territories view.
 *
 * `ALL` is the scope a manager opens The Floor in, so it gets its own picture
 * rather than borrowing a province's: a national trade route at first light,
 * which is the whole footprint and is not any one territory's claim.
 */
export const PLACE_PROMPTS: readonly PlacePrompt[] = [
  {
    code: 'ALL',
    label: 'All territories',
    scene:
      'A long tarred trade route crossing the South African Highveld at first light, ' +
      'straight to the horizon, telephone poles running beside it, dry winter grass ' +
      'on both shoulders, a small town low in the distance under a wide pale sky.',
  },
  {
    code: 'GP',
    label: 'Gauteng',
    scene:
      'A busy inner-city trading street in Johannesburg on a weekday mid-morning: ' +
      'mid-rise concrete buildings, roll-up shutters, informal traders under plain ' +
      'canvas umbrellas, white minibus taxis at the kerb, hard bright Highveld light ' +
      'and short shadows.',
  },
  {
    code: 'GP-TSH',
    label: 'Gauteng North (Tshwane)',
    scene:
      'A wide suburban high street in Pretoria in late October: jacaranda trees in ' +
      'full purple bloom arching over the road, fallen blossom on the tar, low ' +
      'face-brick and sandstone shopfronts, soft overcast light after rain.',
  },
  {
    code: 'GP-EKU',
    label: 'Gauteng East (Ekurhuleni)',
    scene:
      'A petrol-station forecourt on the East Rand late in the afternoon: plain ' +
      'unbranded canopy, two pumps, a flat industrial horizon behind with a pale ' +
      'yellow mine dump and power lines, long low sun and dust in the air.',
  },
  {
    code: 'WC',
    label: 'Western Cape',
    scene:
      'A shopping street in the Cape Flats suburbs of Cape Town at midday, Table ' +
      'Mountain and its cloud far behind the rooftops, single-storey plastered ' +
      'shopfronts with security grilles, a hard blue sky and the southeaster moving ' +
      'the trees.',
  },
  {
    code: 'WC-WIN',
    label: 'Western Cape Winelands',
    scene:
      'The oak-lined main street of a Cape Winelands town in autumn: whitewashed ' +
      'Cape Dutch gables, dappled shade on the pavement, vineyards and blue-grey ' +
      'mountains closing the end of the street, warm clear light.',
  },
  {
    code: 'KZN',
    label: 'KwaZulu-Natal',
    scene:
      'A humid coastal high street in Durban in the early afternoon: faded art-deco ' +
      'facades, deep shop verandas, tall palms, wet tar after a downpour, heavy ' +
      'subtropical light and a bright overcast sky.',
  },
  {
    code: 'KZN-PMB',
    label: 'KwaZulu-Natal Midlands',
    scene:
      'A red-brick Victorian street in Pietermaritzburg on a cold clear morning: ' +
      'iron-lace verandas over the pavement, mist still lying in the green Midlands ' +
      'hills beyond the rooftops, low raking sunlight.',
  },
  {
    code: 'EC-NMB',
    label: 'Eastern Cape – Nelson Mandela Bay',
    scene:
      'A windswept seafront road in Gqeberha: low dunes and marram grass on one ' +
      'side, plain 1960s shopfronts on the other, the grey-green Indian Ocean and a ' +
      'huge sky full of moving cloud, flat bright light.',
  },
  {
    code: 'EC-BCM',
    label: 'Eastern Cape – Buffalo City',
    scene:
      'A quiet river-mouth town street in East London at dusk: faded mid-century ' +
      'shopfronts with deep awnings, wet pavement reflecting the last light, coastal ' +
      'haze softening the far end of the street.',
  },
  {
    code: 'FS',
    label: 'Free State',
    scene:
      'A wide dusty main street in a Free State town on the flat plateau at noon: ' +
      'low single-storey buildings set far back, poplar trees, a bakkie parked at an ' +
      'angle, an enormous pale sky and heat shimmer on the tar.',
  },
  {
    code: 'LP',
    label: 'Limpopo',
    scene:
      'A bushveld trading street on the edge of Polokwane in high summer: red earth ' +
      'verges, a big marula tree over the pavement, low painted concrete shops with ' +
      'plain corrugated awnings, fierce midday sun and sharp black shade.',
  },
  {
    code: 'MP',
    label: 'Mpumalanga',
    scene:
      'A Lowveld town street near Mbombela in the late afternoon: lush subtropical ' +
      'green, flame trees, the dark blue wall of the escarpment behind the rooftops, ' +
      'a thunderstorm building and warm light under the cloud.',
  },
  {
    code: 'NW',
    label: 'North West',
    scene:
      'A platinum-belt town street outside Rustenburg in dry winter: the long ridge ' +
      'of the Magaliesberg behind the roofline, bleached grass, dust hanging over the ' +
      'road, plain low shopfronts and a hazy white sky.',
  },
];

/** The full text sent to the model for one place. */
export function placePrompt(place: PlacePrompt): string {
  return `${place.scene} ${PLACE_STYLE}`;
}
