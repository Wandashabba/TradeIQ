/**
 * The public economic series Ask TradeIQ can cite, and what each one means.
 *
 * A closed list: the refresh job only writes these keys, and the tool only
 * reads them, so a mislabelled figure cannot slip in through a new key.
 */

export type EconomicSource = 'statssa_retail' | 'statssa_cpi' | 'fuel_prices';
export type EconomicUnit = 'pct' | 'c_per_litre' | 'r_per_litre';

export interface SeriesDefinition {
  key: string;
  source: EconomicSource;
  label: string;
  unit: EconomicUnit;
  /** How to read the number, said once so the model never has to infer it. */
  meaning: string;
}

const series = (
  key: string,
  source: EconomicSource,
  label: string,
  unit: EconomicUnit,
  meaning: string,
): SeriesDefinition => ({ key, source, label, unit, meaning });

const RETAIL_YOY = 'Year-on-year % change in retail trade sales at constant prices (real, after inflation).';

export const ECONOMIC_SERIES: readonly SeriesDefinition[] = [
  series('retail_trade_yoy', 'statssa_retail', 'Retail trade sales, all retailers', 'pct', RETAIL_YOY),
  series(
    'retail_trade_yoy_general_dealers',
    'statssa_retail',
    'Retail trade sales, general dealers',
    'pct',
    RETAIL_YOY,
  ),
  series(
    'retail_trade_yoy_food_beverages_tobacco',
    'statssa_retail',
    'Retail trade sales, specialised food, beverages and tobacco stores',
    'pct',
    RETAIL_YOY,
  ),
  series(
    'retail_trade_yoy_pharmaceutical_toiletries',
    'statssa_retail',
    'Retail trade sales, pharmaceutical and medical goods, cosmetics and toiletries',
    'pct',
    RETAIL_YOY,
  ),
  series(
    'retail_trade_yoy_textiles_clothing_footwear',
    'statssa_retail',
    'Retail trade sales, textiles, clothing, footwear and leather goods',
    'pct',
    RETAIL_YOY,
  ),
  series(
    'retail_trade_yoy_household_furniture_appliances',
    'statssa_retail',
    'Retail trade sales, household furniture, appliances and equipment',
    'pct',
    RETAIL_YOY,
  ),
  series(
    'retail_trade_yoy_hardware_paint_glass',
    'statssa_retail',
    'Retail trade sales, hardware, paint and glass',
    'pct',
    RETAIL_YOY,
  ),
  series('retail_trade_yoy_other', 'statssa_retail', 'Retail trade sales, all other retailers', 'pct', RETAIL_YOY),
  series(
    'cpi_headline_yoy',
    'statssa_cpi',
    'Consumer price inflation (CPI), headline',
    'pct',
    'Year-on-year % change in the consumer price index for all urban areas.',
  ),
  series(
    'cpi_food_yoy',
    'statssa_cpi',
    'Consumer price inflation, food and non-alcoholic beverages',
    'pct',
    'Year-on-year % change in the CPI for food and non-alcoholic beverages.',
  ),
  series(
    'fuel_petrol95_inland_change',
    'fuel_prices',
    'Petrol 95 (inland) price adjustment',
    'c_per_litre',
    'Change in the regulated inland 95 ULP petrol price, in cents per litre, taking effect on the first Wednesday of the month. Positive is an increase.',
  ),
  series(
    'fuel_diesel_0005_change',
    'fuel_prices',
    'Diesel 0.005% sulphur price adjustment',
    'c_per_litre',
    'Change in the wholesale price of 0.005% sulphur diesel, in cents per litre, from the first Wednesday of the month. Positive is an increase.',
  ),
  series(
    'fuel_petrol95_inland_price',
    'fuel_prices',
    'Petrol 95 (inland, Gauteng) pump price',
    'r_per_litre',
    'The regulated retail price of 95 ULP petrol in Gauteng after the month\'s adjustment, in rand per litre.',
  ),
];

export const SERIES_BY_KEY: ReadonlyMap<string, SeriesDefinition> = new Map(
  ECONOMIC_SERIES.map((s) => [s.key, s]),
);

export const SOURCE_LABELS: Readonly<Record<EconomicSource, string>> = {
  statssa_retail: 'Stats SA, Retail trade sales (P6242.1)',
  statssa_cpi: 'Stats SA, Consumer Price Index (P0141)',
  fuel_prices: 'Fuel price adjustments (Department of Mineral and Petroleum Resources)',
};
