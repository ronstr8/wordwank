package Wordwank::Schema::Result::Play;
use Moose;
use MooseX::NonMoose;
extends 'DBIx::Class::Core';

__PACKAGE__->table('plays');
__PACKAGE__->load_components(qw/InflateColumn::DateTime TimeStamp/);
__PACKAGE__->add_columns(
    id => {
        data_type => 'bigint',
        is_auto_increment => 1,
    },
    game_id => {
        data_type => 'uuid',
        is_foreign_key => 1,
    },
    player_id => {
        data_type => 'uuid',
        is_foreign_key => 1,
    },
    word => {
        data_type => 'text',
        is_nullable => 0,
    },
    score => {
        data_type => 'integer',
        is_nullable => 0,
    },
    is_auto_submit => {
        data_type => 'boolean',
        default_value => 0,
    },
    created_at => {
        data_type => 'timestamp with time zone',
        set_on_create => 1,
    }
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    game => 'Wordwank::Schema::Result::Game',
    'game_id'
);

__PACKAGE__->belongs_to(
    player => 'Wordwank::Schema::Result::Player',
    'player_id'
);

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
