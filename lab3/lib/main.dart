import 'package:flutter/material.dart';
import 'token.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String token = Token.token;

final HttpLink httpLink = HttpLink(
  'https://api.github.com/graphql',
);

final AuthLink authLink = AuthLink(
  getToken: () async => 'Bearer $token',
  // OR
  // getToken: () => 'Bearer <YOUR_PERSONAL_ACCESS_TOKEN>',
);

final Link link = authLink.concat(httpLink);

ValueNotifier<GraphQLClient> client = ValueNotifier(
  GraphQLClient(
    link: link,
    // The default store is the InMemoryStore, which does NOT persist to disk
    cache: GraphQLCache(store: HiveStore()),
  ),
);

void main() async {
  await initHiveForFlutter();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: client,
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(title: 'Flutter Demo Home Page'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final String readRepositories = """
  query ReadRepositories(\$nRepositories: Int!) {
    search(query:"is:public sort:stars-desc", type:REPOSITORY, first: \$nRepositories) {
      repositoryCount
      pageInfo{
        startCursor
        endCursor
      }
      edges{
        node{
          ... on Repository{
            url
            name
            nameWithOwner
            stargazerCount
            forkCount
            description
            shortDescriptionHTML
          }
        }
      }
    }
  }
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Query(
          options: QueryOptions(
            document: gql(readRepositories),
            variables: const {
              "nRepositories": 20,
            },
            pollInterval: const Duration(seconds: 1000),
            fetchPolicy: FetchPolicy.cacheAndNetwork,
          ),
          builder: (QueryResult result,
              {VoidCallback? refetch, FetchMore? fetchMore}) {
            if (result.hasException) {
              return Text(result.exception.toString());
            }

            if (result.isLoading) {
              return const Text('Loading');
            }

            List? repositories = result.data?['search']?['edges'];

            if (repositories == null) {
              return const Text('No repositories');
            }

            return ListView.builder(
                itemCount: repositories.length,
                itemBuilder: (context, index) {
                  final repository = repositories[index];
                  final Uri url = Uri.parse(repository['node']?['url']);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: InkWell(
                      onTap: () => {launchUrl(url)},
                      child: Ink(
                        color: Colors.grey,
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              repository['node']?['name'] ?? '',
                              style: const TextStyle(fontSize: 20),
                            ),
                            Text(repository['node']?['nameWithOwner'] ?? ''),
                            Text(repository['node']?['shortDescriptionHTML'] ??
                                ''),
                            SizedBox(
                              width: double.infinity,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                textDirection: TextDirection.rtl,
                                children: [
                                  Container(
                                    color: Colors.yellow,
                                    child: Row(
                                      children: <Widget>[
                                        const Text("Stars: "),
                                        Text(repository['node']
                                                    ?['stargazerCount']
                                                .toString() ??
                                            ''),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  Container(
                                    color: Colors.black,
                                    child: Row(
                                      children: <Widget>[
                                        const Text(
                                          "Forks: ",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        Text(
                                          repository['node']?['forkCount']
                                                  .toString() ??
                                              '',
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                });
          },
        ),
      ),
    );
  }
}
