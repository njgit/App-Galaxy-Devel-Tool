use strict;
use warnings;

use App::Cmd::Tester;
use Test::Spec;
use Data::Dumper;
use App::Galaxy::Devel::Tool::App;
use App::Galaxy::Devel::Tool;
use File::Remove qw(remove);
use autobox::Core;
my $tool_dev = App::Galaxy::Devel::Tool->new;

describe "setup" => sub {  
    my ( $result1, $result2, $setup_path);   

    before sub {
       $result1 = test_app( 'App::Galaxy::Devel::Tool::App' => [ qw( setup --path ) ]);
       $setup_path =$tool_dev->local_config_setup_file_path;
    };
    
    it "should give a path (to setup file)" => sub {  
            #warn Dumper $result1;
       is($setup_path,$result1->output->strip);  
    }; 

   before sub {
       $result2 = test_app( 'App::Galaxy::Devel::Tool::App' => [ qw( setup ) ]);
    };
    
    # it "should attempt to install stuff but gets error because no host is defined (because there is no config file)." => sub {    
      # # warn Dumper $result2;
       # is( $result2->stderr->substr(0,19), 'Need to set host at'); 
    # }; 
};

# clean up file
my $setup_file = $tool_dev->local_config_setup_file_path;
remove($setup_file); 

runtests unless caller;	