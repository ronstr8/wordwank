unit module Tilemasters::Validator;

use Cro::HTTP;

class Validator {
    method validate-word(Str $word) {
        my $response = await Cro::HTTP::Client.get("http://wordd/validate/$word");
        return $response.code == 200;
    }
}
