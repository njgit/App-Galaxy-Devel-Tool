use strict;
use warnings;

use App::Cmd::Tester;
use Test::Spec;
use App::Galaxy::Devel::Tool::App;
use App::Galaxy::Devel::Tool;
use Data::Dumper;
use File::Path qw(remove_tree);

my $host = $ARGV[0]; #"ec2-184-73-94-115.compute-1.amazonaws.com";
my $key_path = $ARGV[1];

my $dist_name = "GalaxyX-Tool-test"; 
my $dist_name_suffix = "test";


describe "push" => sub {    
   before sub {
     # make a test distribution 
     remove_tree( $dist_name ) if ( stat( $dist_name ) );         
     my $result1 = test_app( 'App::Galaxy::Devel::Tool::App' => [ 'new', $dist_name_suffix] );
   }; 
   it "should push a distribution to remote and install" => sub {
      SKIP : {
          skip "No pass key and remote host", 1 if ( !defined( @ARGV ) ); 
          my $result2 = test_app( 'App::Galaxy::Devel::Tool::App' => [ 'push', '--host', $host, '--key_path', $key_path, 'GalaxyX-Tool-test' ]);
          like($result2->output, qr/Installing cpan modules/);
      };
   };   
   after all => sub {        
        remove_tree( $dist_name ) if ( stat( $dist_name ) );
    };
};
runtests unless caller;	