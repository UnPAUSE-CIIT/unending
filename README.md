# unending
our game launcher

## some basic info

this game launcher was developed as a way to easily track and distribute games made by UnPAUSE members!

code was written by [@zsfer](https://zsfer.itch.io)
box arts were made by [@edgeworthenvy](https://edgeworthenvy.itch.io)

### steps to use the launcher

**for consumers (still planned)**
1. download a release for ur operating system (this not real yet)
2. run `get-games.bat/.sh` as admin
3. run unending.exe

**for devs**

1. make sure u have these prerequisites
    - [Odin](https://odin-lang.org/)
    - [Make](https://www.gnu.org/software/make/) <- installation varies depending on the OS
2. clone the repo
3. run `make`

# if you have any ideas or bug reports...

create an issue! and make sure to use the proper tags for it too :D

# if you want to contribute...

just fork the repo and create a pull request for your changes!

# logs

### oct 3 log
finished v1.0.0, skipped a bunch of numbers but this is fr the working version.
it only works on linux cuz im using `umu-run` to launch the games, cuz im using linux btw (also cuz we r gona use the steam deck to run the launcher during org weave)

the games themselves arent included in the repo, you have to add them urselves and put them inside their respective folder:
ex.
```
> build/
    > games/
        > MOTHER
            > game.json
            > box_art.png
            > game/ <- put game files here
```

but in the future, i will include a `get-games.bat/.sh` file to batch download the games from itch :)

THO...

**TODO**
- make the launcher work(run games) on windows and mac
- try creating a release build
- 'view on itch' functionality
- add left and right buttons

### oct 2 log
finished v0.0.3, visually all of the components should be there

**TODO**
- make the code cleaner
- implement game launching (through proton/winetricks)

**NICE TO HAVES**
- sort by name/release
