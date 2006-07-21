use Module::Build;
# See perldoc Module::Build for details of how this works

Module::Build->new(
    module_name     => 'Tie::Handle::ToMemory',
    dist_author => 'David A Golden <dagolden@cpan.org>', 
    create_makefile_pl => "traditional",
    create_readme => 1,
    license         => 'perl',
    requires => {
        perl => 5.004,
    },
    recommends => {},
    conflicts => {},
    build_requires  => { 
        Test::Exception => 0.21,
        Test::More => 0.47,
    },
)->create_build_script;
