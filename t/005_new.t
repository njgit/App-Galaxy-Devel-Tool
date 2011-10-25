use App::Cmd::Tester;
use Test::Spec;
use Data::Dumper;
use App::Galaxy::Devel::Tool::App;
use App::Galaxy::Devel::Tool;
use File::stat;
use File::Path qw(remove_tree);

my $dist_name = "GalaxyX-Tool-test"; 
my $dist_name_suffix = "test";
my $custom_tool_dir = "yourTools";

describe "new" => sub {  
    my ( $result1, $result2, $config_path);   

    before sub {        
        remove_tree( $dist_name ) if ( stat( $dist_name ) );         
        $result1 = test_app( 'App::Galaxy::Devel::Tool::App' => [ 'new', $dist_name_suffix] );        
    };
    
    it "should give a dir" => sub {  
            ok( stat( $dist_name ) );  
    }; 
    
    after all => sub {        
        remove_tree( $dist_name ) if ( stat( $dist_name ) );
    };
};
runtests unless caller;	