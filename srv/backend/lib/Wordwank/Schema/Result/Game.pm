package Wordwank::Schema::Result::Game;
use Moose;
use MooseX::NonMoose;
extends 'DBIx::Class::Core';

use Mojo::JSON;
__PACKAGE__->table('games');
__PACKAGE__->load_components(qw/InflateColumn::DateTime TimeStamp/);
__PACKAGE__->add_columns(
    id => {
        data_type => 'uuid',
        is_nullable => 0,
    },
    rack => {
        data_type => 'text[]',
        is_nullable => 0,
    },
    letter_values => {
        data_type => 'jsonb',
        is_nullable => 0,
    },
    started_at => {
        data_type => 'timestamp with time zone',
        is_nullable => 1,
    },
    created_at => {
        data_type => 'timestamp with time zone',
        set_on_create => 1,
    },
    finished_at => {
        data_type => 'timestamp with time zone',
        is_nullable => 1,
    },
    language => {
        data_type => 'varchar',
        size => 10,
        is_nullable => 0,
        default_value => 'en',
    }
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->inflate_column('letter_values', {
    inflate => sub { Mojo::JSON::decode_json(shift) },
    deflate => sub { Mojo::JSON::encode_json(shift) },
});

__PACKAGE__->inflate_column('rack', {
    inflate => sub {
        my $val = shift;
        return $val if ref $val eq 'ARRAY';
        # Postgres text[] comes back as {A,B,C}
        $val =~ s/^\{(.*)\}$/$1/;
        return [ split /,/, $val ];
    },
    deflate => sub { shift },
});

__PACKAGE__->has_many(
    plays => 'Wordwank::Schema::Result::Play',
    'game_id'
);

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
