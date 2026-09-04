/// What is known about a cartridge beyond its file name.
///
/// Small and hand-kept on purpose: a shelf of a dozen says more with a year
/// and one good line each than a scraped database would.
class RomCatalog {
  const RomCatalog._();

  static const _facts = <String, ({int year, String note})>{
    'aladdin': (
      year: 1993,
      note:
          'Disney lent its animators to it, and they drew the frames the '
          'same way they drew the film.',
    ),
    'donkey kong country': (
      year: 1994,
      note:
          'Modelled on Silicon Graphics workstations, then rendered down '
          'to something a 4 MB cartridge could hold.',
    ),
    'mortal kombat': (
      year: 1993,
      note:
          'Nintendo shipped it without the arcade blood. Players noticed, '
          'and the uncensored rival outsold it three to one.',
    ),
    'mortal kombat ii': (
      year: 1994,
      note:
          'The outcry over the first game reached the U.S. Senate. By the '
          'time this one arrived, games carried ratings.',
    ),
    'star fox': (
      year: 1993,
      note:
          'The cartridge brought its own processor — the Super FX drew '
          'polygons the console could not.',
    ),
    'street fighter ii': (
      year: 1992,
      note:
          'Seventy-five dollars at launch, and still the best-selling '
          'thing on the system that was not a Mario game.',
    ),
    'street fighter ii turbo': (
      year: 1993,
      note:
          'The arcade speed-up players had been forcing with a code, sold '
          'as the way the game was meant to run.',
    ),
    'super mario kart': (
      year: 1992,
      note:
          'Mode 7 tilted a flat layer into a road, and every kart racer '
          'since has followed it around the track.',
    ),
    'super mario world': (
      year: 1991,
      note:
          'Yoshi was drawn up in the NES days. He waited for hardware that '
          'could carry him.',
    ),
    'super mario all-stars + super mario world': (
      year: 1994,
      note: 'Four earlier games, repainted in 16-bit, packed beside a fifth.',
    ),
    'teenage mutant ninja turtles iv - turtles in time': (
      year: 1992,
      note:
          'Konami cut a level and added a boss, and the home version ended '
          'up the one people remember.',
    ),
  };

  static ({int year, String note})? forTitle(String title) =>
      _facts[title.toLowerCase()];
}
