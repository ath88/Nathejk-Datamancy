#!/usr/bin/env perl
use Modern::Perl;
use Mojo::mysql;
use File::Slurp;

if (scalar @ARGV < 1) {
  say "Usage: ./lok.pl [lokNumber] [outputfile.geojson]";
  exit();
}

my $lok = $ARGV[0] // 4;
my $outfile = $ARGV[1] // 'out.geojson';

say "Building GeoJSON about [lok $lok] to file [$outfile]";

my $mysql = Mojo::mysql->new('mysql://root@/nathejk15');
my $db = $mysql->db;

my $results = $db->query('
  SELECT
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

  next unless defined $longitude;
  # sometimes, local map coordinates are used. ignoring

  my $string =
     '{
        "type": "Feature",
        "properties": {
          "bandit": "' . $catch->{bandit} . '",
          "sjak": "' . $catch->{sjak} . '"
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
