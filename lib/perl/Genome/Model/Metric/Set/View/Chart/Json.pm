package Genome::Model::Metric::Set::View::Chart::Json;

use strict;
use warnings;

use Genome;

class Genome::Model::Metric::Set::View::Chart::Json {
    is => 'UR::Object::Set::View::Default::Json',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'rule_display',
                {
                    name => 'members',
                    perspective => 'default',
                    toolkit => 'json',
                    aspects => [
                        'build_id',
                        'name',
                        'value'
                    ],
                    subject_class_name => 'Genome::Model::Metric',
                },
            ]
        }
    ]
};

1;
