%% -*- mode: erlang -*-
%% -*- erlang-indent-level: 4;indent-tabs-mode: nil -*-
%% ex: ts=4 sw=4 et
%% Copyright 2011 Benjamin Nortier
%%
%%   Licensed under the Apache License, Version 2.0 (the "License");
%%   you may not use this file except in compliance with the License.
%%   You may obtain a copy of the License at
%%
%%       http://www.apache.org/licenses/LICENSE-2.0
%%
%%   Unless required by applicable law or agreed to in writing, software
%%   distributed under the License is distributed on an "AS IS" BASIS,
%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%   See the License for the specific language governing permissions and
%%   limitations under the License.

-module(node_validation).
-author('Benjamin Nortier <bjnortier@gmail.com>').
-export([geom/1]).
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

geom({struct, Props}) when is_list(Props) ->
    case lists:keyfind(<<"type">>, 1, Props) of
        {<<"type">>, GeomType} ->
            GeomResult = validate_geom_type(GeomType, Props),
	    TransformsResult = 
		    case lists:keyfind(<<"transforms">>, 1, Props) of
			{_, Transforms} ->
			    lists:map(fun transform/1, Transforms);
			false ->
			    [ok]
		    end,
	    compact_errors([GeomResult|TransformsResult]);
	_ ->
	    {error, {struct, [{<<"missing">>, <<"geometry type">>}]}}
    end;
geom(_) ->
    {error, {struct, [{<<"invalid">>, <<"geometry">>}]}}.


transform({struct, Props}) when is_list(Props) ->
    io:format("~p~n", [Props]),
    case lists:keyfind(<<"type">>, 1, Props) of
        {<<"type">>, TransformType} ->
            X = validate_transform_type(TransformType, Props),
	    io:format("~p~n", [X]),
	    X;
        _ ->
            {error, {struct, [{<<"missing">>, <<"tranform type">>}]}}
    end;
transform(_) ->
    {error, {struct, [{<<"invalid">>, <<"transform">>}]}}.
    

-ifdef(TEST).
validate_geom_test_() ->
    Origin = {struct, [{<<"x">>, 0},
		       {<<"y">>, 0},
		       {<<"z">>, 0}]},
    [
     ?_assertEqual(ok,
		   geom({struct, [{<<"type">>, <<"sphere">>},
				  {<<"origin">>, Origin},
				  {<<"parameters">>, {struct, [
							       {<<"r">>, 1.2}
							      ]}}]})),
     ?_assertEqual(ok,
		   geom({struct, [{<<"type">>, <<"union">>},
				  {<<"children">>, [<<"abc">>, <<"123">>]}]})),
     ?_assertEqual({error, {struct, [{<<"r">>,<<"must be positive">>}]}},
		   geom({struct, [{<<"type">>, <<"sphere">>},
				  {<<"origin">>, Origin},
				  {<<"parameters">>, {struct, [
							       {<<"r">>, -0.3}
							      ]}}]})),
     ?_assertEqual({error, {struct, [{<<"factor">>,<<"must be positive">>}]}},
		   geom({struct, [{<<"type">>, <<"sphere">>},
				  {<<"origin">>, Origin},
				  {<<"parameters">>, {struct, [
							       {<<"r">>, 3}
							      ]}},
				  {<<"transforms">>,
				   [{struct, [{<<"type">>, <<"scale">>},
					      {<<"origin">>, Origin},
					      {<<"parameters">>, {struct, [{<<"x">>, 0.0},
									   {<<"y">>, 3},
									   {<<"z">>, 0.0},
									   {<<"factor">>, <<"a">>}]}}]}]}]}))

    ].
-endif.


validate_geom_type(<<"sphere">>, Props) ->
    validate_primitive(Props, [
			       {<<"r">>, fun positive/1}
			      ]);
validate_geom_type(<<"cuboid">>, Props) ->
    validate_primitive(Props, [
				    {<<"u">>, fun not_zero/1},
				    {<<"v">>, fun not_zero/1},
				    {<<"w">>, fun not_zero/1}
				   ]);
validate_geom_type(<<"cylinder">>, Props) ->
    validate_primitive(Props, [
			       {<<"r">>, fun positive/1},
			       {<<"h">>, fun not_zero/1}
			      ]);
validate_geom_type(<<"cone">>, Props) ->
    validate_primitive(Props, [
			       {[<<"r1">>, <<"r2">>], fun one_zero_one_positive/1},
			       {[<<"r1">>, <<"r2">>], fun not_equal/1},
			       {<<"h">>, fun not_zero/1}
			      ]);
validate_geom_type(<<"wedge">>, Props) ->
    validate_primitive(Props, [
			       {<<"u1">>, fun positive/1},
			       {<<"u2">>, fun positive_or_zero/1},
			       {<<"v">>, fun positive/1},
			       {<<"w">>, fun not_zero/1}
			      ]);
validate_geom_type(<<"torus">>, Props) ->
    validate_primitive(Props, [
			       {<<"r1">>, fun positive/1},
			       {<<"r2">>, fun positive/1}
			      ]);
validate_geom_type(<<"union">>, Props) ->
    validate_boolean(Props);
validate_geom_type(<<"subtract">>, Props) ->
    validate_boolean(Props);
validate_geom_type(<<"intersect">>, Props) ->
    validate_boolean(Props);
validate_geom_type(_, _) ->
    {error, {struct, [{<<"invalid">>, <<"unknown geometry type">>}]}}.

validate_primitive(Props, Specs) ->
    case lists:keyfind(<<"origin">>, 1, Props) of
	false ->
	    {error, {struct, [{<<"missing">>, <<"origin">>}]}};
	{_, Origin} ->
	    case validate_origin(Origin) of
		ok ->
		    case lists:keyfind(<<"parameters">>, 1, Props) of
			false ->
			    {error, {struct, [{<<"missing">>, <<"parameters">>}]}};
			{_, Parameters} ->
			    validate_parameters(Parameters, Specs)
		    end;
		Error ->
		    Error
	    end
		
    end.

validate_origin(Origin) ->
    validate_parameters(Origin, [
				 {<<"x">>, fun number/1},
				 {<<"y">>, fun number/1},
				 {<<"z">>, fun number/1}
				]).
    

validate_boolean(Props) ->
    case lists:keyfind(<<"children">>, 1, Props) of
	false ->
	    {error, {struct, [{<<"missing">>, <<"children">>}]}};
	{_, Children} when is_list(Children) ->
	    ok;
	_ ->
	    {error, {struct, [{<<"invalid">>, <<"children">>}]}}
    end.

    
-ifdef(TEST).
validate_geom_type_test_() ->
    Origin = {struct, [{<<"x">>, 0},
		       {<<"y">>, 0},
		       {<<"z">>, 0}]},
    [
     ?_assertEqual(
        ok, 
        validate_geom_type(<<"sphere">>, [{<<"origin">>, Origin},
					  {<<"parameters">>, 
					   {struct, [{<<"r">>, 0.1}]}}])),
     ?_assertEqual(
        {error, {struct, [{<<"r">>, <<"not found">>}]}}, 
        validate_geom_type(<<"sphere">>, [{<<"origin">>, Origin},
					  {<<"parameters">>, 
					   {struct, []}}])),
     ?_assertEqual(
        {error, {struct, [{<<"r">>, <<"must be positive">>}]}}, 
        validate_geom_type(<<"sphere">>, [{<<"origin">>, Origin},
					  {<<"parameters">>, 
					   {struct, [{<<"r">>, -4}]}}])),
     ?_assertEqual(
        {error, {struct, [{<<"u">>, <<"cannot be zero">>},
			  {<<"w">>, <<"cannot be zero">>}]}}, 
        validate_geom_type(<<"cuboid">>, [{<<"origin">>, Origin},
					  {<<"parameters">>,
					   {struct, [{<<"u">>, 0},
						     {<<"v">>, 3.1},
						     {<<"w">>, 0}
						    ]}}]))
    ].
-endif.

validate_transform_type(<<"translate">>, Props) ->
    validate_primitive(Props, [{<<"u">>, fun number/1},
			       {<<"v">>, fun number/1},
			       {<<"w">>, fun number/1},
			       {<<"n">>, fun positive_or_zero/1}
			      ]);
validate_transform_type(<<"scale">>, Props) ->
    validate_primitive(Props, [
			       {<<"factor">>, fun positive/1}
			      ]);
validate_transform_type(<<"rotate">>, Props) ->
    validate_primitive(Props, [
			       {<<"u">>, fun number/1},
			       {<<"v">>, fun number/1},
			       {<<"w">>, fun number/1},
			       {<<"angle">>, fun positive/1},
			       {<<"n">>, fun positive_or_zero/1}
			      ]);
validate_transform_type(<<"mirror">>, Props) ->
    validate_primitive(Props, [
			       {<<"u">>, fun number/1},
			       {<<"v">>, fun number/1},
			       {<<"w">>, fun number/1},
			       {<<"n">>, fun zero_or_one/1}
			      ]);
validate_transform_type(_, _) ->
    {error, {struct, [{<<"invalid">>, <<"transform">>}]}}.


    


-ifdef(TEST).
validate_transform_type_test_() ->
    Origin = {struct, [{<<"x">>, 0},
		       {<<"y">>, 0},
		       {<<"z">>, 0}]},
    [
     ?_assertEqual(
        ok, 
        validate_transform_type(<<"scale">>, [{<<"origin">>, Origin},
					      {<<"parameters">>, 
					       {struct, [{<<"x">>, 0.1},
							 {<<"y">>, 0},
							 {<<"z">>, -5},
							 {<<"factor">>, 2}
							]}}])),
     ?_assertEqual(
        {error, {struct, [{<<"factor">>, <<"must be positive">>}
			 ]}}, 
        validate_transform_type(<<"scale">>, [{<<"origin">>, Origin},
					      {<<"parameters">>, 
					       {struct, [{<<"x">>, 0.1},
							 {<<"y">>, <<"a">>},
							 {<<"z">>, -5},
							 {<<"factor">>, -0.1}
							]}}]))
    ].
-endif.

validate_parameters(Parameters, Specs) ->
    Errors = lists:foldr(fun(Spec, Acc) ->
                                 case validate_spec(Parameters, Spec) of
                                     ok ->
                                         Acc;
				     Errors when is_list(Errors) ->
					 Errors ++ Acc;
                                     Error ->
                                         [Error|Acc]
                                 end
                         end,
                         [],
                         Specs),
    case Errors of
        [] ->
            ok;
        _ ->
            {error, {struct, Errors}}
    end.

-ifdef(TEST).
validate_parameters_test_() ->
    [
     ?_assertEqual(
        ok, 
        validate_parameters({struct, [{<<"a">>, 0.1},
                                      {<<"b">>, 3}]},
                            [
                             {<<"a">>, fun positive/1},
                             {<<"b">>, fun positive/1}
                            ])),

     ?_assertEqual(
        {error, {struct, [{<<"b">>, <<"must be positive">>}]}}, 
        validate_parameters({struct, [{<<"a">>, 0.1},
                                      {<<"b">>, -3}]},
                            [
                             {<<"a">>, fun positive/1},
                             {<<"b">>, fun positive/1}
                            ])),
     
     ?_assertEqual(
        {error, {struct, [{<<"a">>, <<"must be positive">>},
			  {<<"b">>, <<"must be positive">>}]}},
        validate_parameters({struct, [{<<"b">>, -0.6},
                                      {<<"a">>, -20}]},
                            [
                             {<<"a">>, fun positive/1},
                             {<<"b">>, fun positive/1}
                            ])),
     ?_assertEqual(
        {error, {struct, [{<<"a">>, <<"one must be positive">>},
			  {<<"b">>, <<"one must be positive">>}]}},
        validate_parameters({struct, [{<<"b">>, 0},
                                      {<<"a">>, 0}]},
                            [
                             {[<<"a">>, <<"b">>], fun one_zero_one_positive/1}
                            ]))
    ].
-endif.


validate_spec({struct, ParameterProps}, {Fields, CheckFn}) when is_list(Fields) ->
    Values = lists:foldr(fun(Field, Acc) ->
				 case lists:keyfind(Field, 1, ParameterProps) of
				     false -> 
					 Acc;
				     {_, Value} ->
					 [Value|Acc]
				 end
			 end,
			 [],
			 Fields),
    NumberOfFields = length(Fields),
    case length(Values) of
	NumberOfFields ->
	    case CheckFn(Values) of
                ok ->
                    ok;
                {error, Reason} ->
		    [{Field, Reason} || Field <- Fields]
            end; 
	_ ->
	    {Fields, <<"not found">>}
    end;
validate_spec({struct, ParameterProps}, {Field, CheckFn}) ->
    case lists:keyfind(Field, 1, ParameterProps) of
        false ->
            {Field, <<"not found">>};
        {_, Value} ->
            case CheckFn(Value) of
                ok ->
                    ok;
                {error, Reason} ->
                    {Field, Reason}
            end;
        _ ->
            ok
    end.

positive(Value) when is_integer(Value) andalso Value > 0 ->
    ok;
positive(Value) when is_float(Value) andalso Value > 0 ->
    ok;
positive(_) ->
    {error, <<"must be positive">>}.

positive_or_zero(Value) when is_integer(Value) andalso Value >= 0 ->
    ok;
positive_or_zero(Value) when is_float(Value) andalso Value >= 0 ->
    ok;
positive_or_zero(_) ->
    {error, <<"must be positive">>}.


positive_integer(Value) when is_integer(Value) andalso Value > 0 ->
    ok;
positive_integer(_) ->
    {error, <<"must be a positive integer">>}.

number(Value) when is_integer(Value) orelse is_float(Value) ->
    ok;
number(_) ->
    {error, <<"must be a number">>}.

one_zero_one_positive([A, B]) when A > 0 andalso B >= 0 ->
    ok;
one_zero_one_positive([A, B]) when B > 0 andalso A >= 0 ->
    ok;
one_zero_one_positive(_) ->
    {error, <<"one must be positive">>}.

not_equal([A, B]) when A =:= B ->
    {error, <<"can't be equal">>};
not_equal(_) ->
    ok.

not_zero(Value) when is_integer(Value) andalso Value =/= 0 ->
    ok;
not_zero(Value) when is_float(Value) andalso Value =/= 0 ->
    ok;
not_zero(_) ->
    {error, <<"cannot be zero">>}.

zero_or_one(Value) when is_integer(Value) andalso Value =:= 0 ->
    ok;
zero_or_one(Value) when is_integer(Value) andalso Value =:= 1 ->
    ok;
zero_or_one(_) ->
    {error, <<"must be 0 or one">>}.


-ifdef(TEST).
validate_spec_test_() ->
    [
     ?_assertEqual(ok, 
                   validate_spec({struct, [{<<"a">>, 0.1}]}, {<<"a">>, fun positive/1})),
     ?_assertEqual({<<"a">>, <<"must be positive">>}, 
                   validate_spec({struct, [{<<"a">>, 0}]}, {<<"a">>, fun positive/1})),
     ?_assertEqual({<<"a">>, <<"not found">>}, 
                   validate_spec({struct, []}, {<<"a">>, fun positive/1})),
     ?_assertEqual({<<"a">>, <<"must be a positive integer">>}, 
                   validate_spec({struct, [{<<"a">>, 0}]}, {<<"a">>, fun positive_integer/1})),
     ?_assertEqual({<<"a">>, <<"must be a number">>}, 
                   validate_spec({struct, [{<<"a">>, <<"x">>}]}, {<<"a">>, fun number/1})),
     ?_assertEqual([{<<"a">>, <<"one must be positive">>},
		    {<<"b">>, <<"one must be positive">>}],
                   validate_spec({struct, [{<<"a">>, 0},
					   {<<"b">>, 0}]}, 
				 {[<<"a">>,<<"b">>], fun one_zero_one_positive/1})),
     ?_assertEqual([{<<"a">>, <<"can't be equal">>},
		    {<<"b">>, <<"can't be equal">>}],
                   validate_spec({struct, [{<<"a">>, 1},
					   {<<"b">>, 1}]}, 
				 {[<<"a">>,<<"b">>], fun not_equal/1}))

     
    ].
-endif.


compact_errors(Results) ->
    CompactedProps = lists:foldl(fun(ok, Acc) ->
					 Acc;
				    ({error, {struct, Props}}, Acc) ->
					 Acc ++ Props
				 end,
				 [],
				 Results),
    case CompactedProps of
	[] ->
	    ok;
	_ ->
	    {error, {struct, CompactedProps}}
    end.

    
-ifdef(TEST).
compact_errors_test_() ->
    [
     ?_assertEqual(ok, compact_errors([ok, ok, ok, ok])),
     ?_assertEqual({error, {struct, [x, y]}}, 
		   compact_errors([ok, {error, {struct, [x]}}, ok, {error, {struct, [y]}}]))
    ].
-endif.

    

