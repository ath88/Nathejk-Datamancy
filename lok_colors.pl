#!/usr/bin/env perl
use Modern::Perl;
use Mojo::mysql;
use File::Slurp;
use DateTime;
use Encode::Encoder qw(encoder);
use JSON qw(encode_json);

if (scalar @ARGV < 0) {
  say "Usage: ./lok_colors.pl [outputfile.geojson]";
  exit();
}

my $outfile = $ARGV[0] // 'out.geojson';

say "Building GeoJSON to file [$outfile]";

my $mysql = Mojo::mysql->new('mysql://root@/nathejk15');
my $db = $mysql->db;

my %color_mem = ();
my @colors = (
  '#a6cee3', '#1f78b4', '#b2df8a', '#33a02c',
  '#fb9a99', '#e31a1c', '#fdbf6f', '#ff7f00',
  '#cab2d6', '#6a3d9a', '#ffff99', '#b15928'
);

$db->query('SET NAMES latin1');
my $results = $db->query('
  SELECT
    nathejk_checkIn.createdUts AS tid,
    nathejk_member.title AS bandit,
    nathejk_team.title AS sjak,
    lokNumber AS lok,
    location
  FROM nathejk_checkIn
    JOIN nathejk_member
    ON nathejk_member.id = memberId
    JOIN nathejk_team
    ON nathejk_member.teamId = nathejk_team.id
  WHERE isCaught = 1
;')->hashes->to_array;

my @features;
foreach my $catch (@{$results}) {
  my @geo = split(':', $catch->{location});
  my $latitude = $geo[0];
  my $longitude = $geo[1];

  # sometimes local map coordinates are used. ignoring those
  next unless defined $longitude;

  my $color = select_color($catch->{lok});
  my $dt = DateTime->from_epoch({epoch => $catch->{tid}});
  my $time = $dt->hms . ' ' . $dt->dmy;

  my $feature = {
    type => 'Feature',
    properties => {
      lok => $catch->{lok},
      bandit => $catch->{bandit},
      sjak => $catch->{sjak},
      tidspunkt => $time,
      'marker-color' => $color
    },
    geometry => {
      type => 'Point',
      coordinates => [0+$longitude, 0+$latitude]
    }
  };

  push(@features, $feature);
}

my $geojson = {type => 'FeatureCollection', features => \@features};

write_file($outfile,  encoder(JSON->new->pretty->encode($geojson))->bytes('iso-8859-15')->utf8);

sub select_color {
  my $sjak = shift;
  return $color_mem{$sjak} if (exists $color_mem{$sjak});
  $color_mem{$sjak} = pop(@colors);
  return $color_mem{$sjak};
}