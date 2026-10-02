import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

/// THE THIRTEEN SEEDED TERRITORIES, exactly as `backend/scripts/seed/catalog.ts`
/// has them — names, codes and the Inland/Coastal `region`.
///
/// Copied rather than derived, on purpose: the grouping rule in
/// `dashboard_filters.dart` is a claim about *these strings* — the en dash in
/// the Eastern Cape names, the three codes that are also prefixes, the four
/// that are not, and the `region` column that looks like a province and is
/// not. A fixture that drifted from the seed would make the rule's tests
/// agree with themselves and with nothing else.
///
/// The ids are the test's own (`t-gp` rather than `demo-territory-gp`), because
/// nothing in the rule reads an id — it reads codes and names.
const List<Territory> seededTerritories = <Territory>[
  Territory(id: 't-gp', name: 'Gauteng', code: 'GP', region: 'Inland'),
  Territory(id: 't-wc', name: 'Western Cape', code: 'WC', region: 'Coastal'),
  Territory(id: 't-kzn', name: 'KwaZulu-Natal', code: 'KZN', region: 'Coastal'),
  Territory(
    id: 't-gp-tsh',
    name: 'Gauteng North (Tshwane)',
    code: 'GP-TSH',
    region: 'Inland',
  ),
  Territory(
    id: 't-gp-eku',
    name: 'Gauteng East (Ekurhuleni)',
    code: 'GP-EKU',
    region: 'Inland',
  ),
  Territory(
    id: 't-wc-win',
    name: 'Western Cape Winelands',
    code: 'WC-WIN',
    // NOT a mistake, and not a province: the seed really does file the
    // Winelands as Inland. It is the clearest single reason the rule cannot
    // read `region`.
    region: 'Inland',
  ),
  Territory(
    id: 't-kzn-pmb',
    name: 'KwaZulu-Natal Midlands',
    code: 'KZN-PMB',
    region: 'Inland',
  ),
  Territory(
    id: 't-ec-nmb',
    // An EN DASH (U+2013), not a hyphen.
    name: 'Eastern Cape – Nelson Mandela Bay',
    code: 'EC-NMB',
    region: 'Coastal',
  ),
  Territory(
    id: 't-ec-bcm',
    name: 'Eastern Cape – Buffalo City',
    code: 'EC-BCM',
    region: 'Coastal',
  ),
  Territory(id: 't-fs', name: 'Free State', code: 'FS', region: 'Inland'),
  Territory(id: 't-lp', name: 'Limpopo', code: 'LP', region: 'Inland'),
  Territory(id: 't-mp', name: 'Mpumalanga', code: 'MP', region: 'Inland'),
  Territory(id: 't-nw', name: 'North West', code: 'NW', region: 'Inland'),
];
