'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "0731e457b15f0b97b5e5160cf49aaf0e",
"version.json": "498d2dcc5ba3b2cbb5b38a66e175f295",
"pricelist.html": "6048dea26185e2353564a8a582c053ba",
"index.html": "a8adc51a26e28e540c1c7aa4432513a4",
"/": "a8adc51a26e28e540c1c7aa4432513a4",
"firebase-messaging-sw.js": "3ec42b8939d9297c8d96623c1b134d4c",
"main.dart.js": "53da8aa839e648172f65d1edf2a3feb1",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"favicon.png": "73f59fb28e3833c2b37fd7588bfa0c6c",
"pricelist.js": "46ddf2f0fa32df3fb3c67ad6d7309685",
"icons/Icon-192.png": "506f0480609dd7166c863057bb40c855",
"icons/Icon-maskable-192.png": "506f0480609dd7166c863057bb40c855",
"icons/Icon-maskable-512.png": "aded54263238a1563e18b2376d3e9cfa",
"icons/Icon-512.png": "aded54263238a1563e18b2376d3e9cfa",
"manifest.json": "acb1f615a6f679aefc5cf37338b4ed61",
"assets/NOTICES": "70c292a869a208f1aeea3996ee96c3f8",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "9dde7d9ac3727fee722acbb2c4058765",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/packages/clotheline_core/assets/images/app_qr.png": "0a400a00b680bfc720909a5cc7f90f14",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/AssetManifest.bin": "7a6856460f1f8e1ca35c9c7a501b6a28",
"assets/fonts/MaterialIcons-Regular.otf": "a4f3ac3657b4acd714b91671d172d733",
"assets/assets/images/avatars/a_6.png": "d7ef34b56355f091be7c2543928b9bf2",
"assets/assets/images/avatars/a_7.png": "271c90b604e2b20986e248f16ecf9bf9",
"assets/assets/images/avatars/a_5.png": "19beb516e4427ac82fc85b953e80e87d",
"assets/assets/images/avatars/a_4.png": "ae9df3bbde1aa2a5feda612000089bc1",
"assets/assets/images/avatars/a_1.png": "8f31d81911c19918fb481439f77a3d38",
"assets/assets/images/avatars/a_3.png": "05782fb18f7203264d95244bafc22d67",
"assets/assets/images/avatars/a_2.png": "07b5905ac14791a4fdfab786b0350428",
"assets/assets/images/avatars/u_15.png": "7ccde812e142dab656918e3c2cf3b7e1",
"assets/assets/images/avatars/u_14.png": "797f1df91cb958d74bff2c6941151291",
"assets/assets/images/avatars/u_9.png": "4a8bb54589a2ce42c7e98345d7366b1d",
"assets/assets/images/avatars/u_16.png": "4fe551499be08b8fb1514d705313baf6",
"assets/assets/images/avatars/u_17.png": "ab8bbf1361d80c5d0e623bb766d10256",
"assets/assets/images/avatars/u_8.png": "be2a2c1af18df1b5f47baea869894b55",
"assets/assets/images/avatars/u_13.png": "5dbcc69b96086a7ed03eacf7acb50f8d",
"assets/assets/images/avatars/u_12.png": "44542da6e210478bbb7f9f499aff6b25",
"assets/assets/images/avatars/u_10.png": "1d2e2510f184d790fa12da8408aee683",
"assets/assets/images/avatars/u_11.png": "436893490e446f6094b0154df8961137",
"assets/assets/images/avatars/a_10.png": "1e0d30df2955eb603adc642cf652bbeb",
"assets/assets/images/avatars/u_3.png": "fac912964aec4b520607c972c775422d",
"assets/assets/images/avatars/u_20.png": "faaeddd75ac1a6899966b14d4bfb72da",
"assets/assets/images/avatars/u_2.png": "6be0ede5efe441a6c7ef54ce77ff98b9",
"assets/assets/images/avatars/u_1.png": "60f62902d27d6b817589f82d67dfe5db",
"assets/assets/images/avatars/u_5.png": "875cba6a4b22f94ecdf70b7bfe3ba2ac",
"assets/assets/images/avatars/u_4.png": "bd985752be7f8f10b88973afd8573707",
"assets/assets/images/avatars/u_6.png": "7941f3fcf5fbff6326292de178c8a62c",
"assets/assets/images/avatars/u_19.png": "31076e21349fa3945d3b4e0da509f1a4",
"assets/assets/images/avatars/u_18.png": "fe25bd2a1eacad15af56138a69e7d79d",
"assets/assets/images/avatars/u_7.png": "e115cf3e9b910f42ecd449f636e52b6b",
"assets/assets/images/avatars/a_9.png": "c71df96be897b5b98cfb661382a0356b",
"assets/assets/images/avatars/a_8.png": "a414f37e56ec8d95b37a6fc0adde1c63",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
