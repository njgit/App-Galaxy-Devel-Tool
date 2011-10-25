use strict;
use warnings;

use App::Cmd::Tester;
use Test::Spec;
use Data::Dumper;
use App::Galaxy::Devel::Tool::App;
use App::Galaxy::Devel::Tool;
use File::Remove qw(remove);
use File::stat;
use Path::Class qw(file);
use autobox::Core;

my $tool_dev = App::Galaxy::Devel::Tool->new;

describe "save" => sub {  
    my ( $result1, $result2, $config_path);   

    before sub {
       my $file = file('td/fake_key.pem');
       my $abs = $file->absolute;
       $result1 = test_app( 'App::Galaxy::Devel::Tool::App' => [ qw(save --key_path), $abs, qw(--host fake.domain.net) ]);
       $config_path = $tool_dev->local_config_file_path;
    };
    
    it "should give a path (to config file)" => sub {  
         
            ok( stat( $config_path) );  
    }; 
};
runtests unless caller;	

