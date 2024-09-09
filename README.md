# FancyErrors - No more model ERRORs

## Description
Are you tired of your clients or friends having errors even though you thought that models were downloaded on their end? Well, feel free to install this addon and no longer have this problem!
No, this is not a :SetModel call, this is a bit more complicated.

## Who may need that?
Servers with lots of addons that add new models.
People that install tons of addons that just don't end up downloaded on other clients.
Developers and modelmakers that forget to uninstall their addons when playing with friends.
...and many more

## How this works?
In short, when CLIENT doesn't have a model, it requests a model mesh from SERVER, which constructs and sends the said mesh to the CLIENT. When it has been transported, CLIENT overrides rendering of the entity to draw transported mesh instead of ERROR. For ragdolls, SERVER also starts to send regular messages about bone positions on the ragdoll. Created meshes are automatically destroyed when unused and on lua exit, making it as optimised as possible.

## Special thanks
- [DEPRECATED] LeySexyErrors at gmodstore - for initial inspiration.
- Meetric - for help with mesh lighting
