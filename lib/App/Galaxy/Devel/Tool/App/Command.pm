package App::Galaxy::Devel::Tool::App::Command;
use App::Cmd::Setup -command;

sub opt_spec {
    my ( $class, $app ) = @_;
    return (
      [ 'help' => "This usage screen" ],
      $class->options($app),
    )
  }

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    die $self->_usage_text if $opt->{help};
    $self->validate( $opt, $args );
  }
  
1;    