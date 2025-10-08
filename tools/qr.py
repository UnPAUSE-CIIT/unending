from pathlib import Path
import json
import qrcode

game_dir = Path('../build/games')

for g in game_dir.glob('*/game.json'):
    print(f'creating qr for {g}')
    with open(g, 'r') as f:
        data = json.load(f)
    # qr = qrcode.QRCode(
    #     version=1,
    #     border=1,
    # )
    # qr.add_data(data['download_link'])
    # qr.make(fit=True)
    # img = qr.make_image()

    img = qrcode.make(data['download_link'])
    img.save(f'{g.parent}/qr.png')
