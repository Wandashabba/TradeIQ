/**
 * Prompt set for TradeIQ's brand illustration series.
 *
 * Four slots, one visual language: calm, abstract-retail, tinted around the
 * brand blue #0A6CF0. The shared style suffix is appended to every prompt so
 * the four images read as one series, not four stock finds. Prompts must
 * never ask for text, logos or people — this is ambient art, not content.
 *
 * Slugs map 1:1 to the fields of `app/lib/core/brand_media.dart`.
 */

/** Appended to every prompt — the series' shared art direction. */
export const styleSuffix =
  'Minimalist abstract illustration, calm and premium, soft matte gradients ' +
  'in a cool blue palette built around the brand blue #0A6CF0, generous ' +
  'negative space, flat geometric shapes with gentle depth, subtle film ' +
  'grain, consistent series style. No text, no letters, no numbers, no ' +
  'logos, no watermarks, no people, no faces, no hands.';

/**
 * @type {{slug: string, aspectRatio: string, prompt: string}[]}
 * `aspectRatio` must be one of the Imagen-supported ratios
 * (1:1, 3:4, 4:3, 9:16, 16:9).
 */
export const prompts = [
  {
    slug: 'tasks-all-clear',
    aspectRatio: '4:3',
    prompt:
      'A calm, perfectly stocked retail shelf seen straight on, every item ' +
      'in its place, ordered and serene, soft morning light across tidy ' +
      'rows of simple abstract product shapes.',
  },
  {
    slug: 'no-alerts',
    aspectRatio: '4:3',
    prompt:
      'A quiet storefront at dawn, shutters just opened, empty street, ' +
      'still air, first soft light on the glass, peaceful and unhurried, ' +
      'abstract simplified architecture.',
  },
  {
    slug: 'empty-generic',
    aspectRatio: '4:3',
    prompt:
      'Abstract shelving geometry: a rhythmic grid of empty shelf planes ' +
      'and uprights dissolving into soft light, architectural and airy, ' +
      'pure form without any products.',
  },
  {
    slug: 'menu-header',
    aspectRatio: '16:9',
    prompt:
      'Wide banner composition: an abstract supermarket aisle in one-point ' +
      'perspective receding into soft light, long horizontal lines of ' +
      'shelving planes, spacious and cinematic.',
  },
];
