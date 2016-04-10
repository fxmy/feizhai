-module(memes).
%-compile([export_all]).
-export([rand/0]).

rand() ->
	Meme = element(rand:uniform(tuple_size(memes())), memes()),
	Kaomoji = element(rand:uniform(tuple_size(kaomoji())), kaomoji()),
	<<Meme/binary,Kaomoji/binary>>.
	%<<element(rand:uniform(tuple_size(memes())), memes()),element(rand:uniform(tuple_size(kaomoji())), kaomoji())>>.

memes() ->
	{<<"这是芦苇"/utf8>>,
	 <<"今日之我已不是昨日之我！"/utf8>>
	}.

kaomoji() ->
	{<<"(*^ω^)"/utf8>>,
	 <<"ヽ(　￣д￣)ノ"/utf8>>,
	 <<"(*ﾟ∇ﾟ)"/utf8>>
	}.
