#!/usr/bin/env perl
use Modern::Perl;
use Mojo::mysql;
use File::Slurp;
use DateTime;

if (scalar @ARGV < 1) {
  say "Usage: ./lok.pl [lokNumber] [outputfile.geojson]";
  exit();
}

my $lok = $ARGV[0] // 4;
my $outfile = $ARGV[1] // 'out.geojson';

say "Building GeoJSON about [lok $lok] to file [$outfile]";

my $mysql = Mojo::mysql->new('mysql://root@/nathejk15');
my $db = $mysql->db;

my @colors = (
  '#a6cee3', '#1f78b4', '#b2df8a', '#33a02c',
  '#fb9a99', '#e31a1c', '#fdbf6f', '#ff7f00',
  '#cab2d6', '#6a3d9a', '#ffff99', '#b15928'
);

my %color_mem = ();

my $results = $db->query('
  SELECT
    nathejk_checkIn.createdUts AS tidspunkt,
    nathejk_member.title AS bandit,
    nathejk_team.title AS sjak,
    location
  FROM nathejk_checkIn
    JOIN nathejk_member
    ON nathejk_member.id = memberId
    JOIN nathejk_team
    ON nathejk_member.teamId = nathejk_team.id
  WHERE lokNumber = ?;'
, $lok)->hashes->to_array;


my @features;
foreach my $catch (@{$results}) {
  my @geo = split(':', $catch->{location});
  my $latitude = $geo[0];
  my $longitude = $geo[1];

  # sometimes local map coordinates are used. ignoring those
  next unless defined $longitude;

  my $color = select_color($catch->{sjak});
  my $dt = DateTime->from_epoch({epoch => $catch->{tidspunkt}});
  my $time = $dt->hms . ' ' . $dt->dmy;

  my $string =
     '{
        "type": "Feature",
        "properties": {
          "bandit": "' . $catch->{bandit} . '",
          "sjak": "' . $catch->{sjak} . '",
          "tidspunkt": "' . $time . '",
          "marker-color": "' . $color . '"
        },
        "geometry": {
          "type": "Point",
          "coordinates": [
            ' . $longitude . ',
            ' . $latitude . '
          ]
        }
      }';

  push(@features, $string);
}

my $geojson = '{"type": "FeatureCollection","features": [' . join(',', @features) . ']}';

write_file($outfile, {binmode => ':utf8'}, $geojson);


sub select_color {
  my $sjak = shift;
  return $color_mem{$sjak} if (exists $color_mem{$sjak});
  $color_mem{$sjak} = pop(@colors);
  return $color_mem{$sjak};
}