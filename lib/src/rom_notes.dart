/// One line about a cartridge, shown beside it on the shelf.
class RomNotes {
  const RomNotes._();

  static const _notes = <String, String>{
    'donkey kong country':
        'Modelled on Silicon Graphics workstations, then rendered down '
        'to something a 4 MB cartridge could hold.',
    'mortal kombat':
        'Nintendo shipped it without the arcade blood. Players noticed, '
        'and the uncensored rival outsold it three to one.',
    'mortal kombat ii':
        'The outcry over the first game reached the U.S. Senate. By the '
        'time this one arrived, games carried ratings.',
    'star fox':
        'The cartridge brought its own processor — the Super FX drew '
        'polygons the console could not.',
    'street fighter ii':
        'Seventy-five dollars at launch, and still the best-selling '
        'thing on the system that was not a Mario game.',
    'super mario kart':
        'Mode 7 tilted a flat layer into a road, and every kart racer '
        'since has followed it around the track.',
    'super mario world':
        'Yoshi was drawn up in the NES days. He waited for hardware that '
        'could carry him.',
    'super mario all-stars + super mario world':
        'Four earlier games, repainted in 16-bit, packed beside a fifth.',
  };

  static String? forTitle(String title) => _notes[title.toLowerCase()];
}
