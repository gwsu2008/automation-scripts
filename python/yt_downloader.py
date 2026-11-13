import yt_dlp
import argparse

def download_video(url, file_type):
    ydl_opts = {'outtmpl': '%(title)s.%(ext)s'}
    if file_type == 'm4a':
        print("Downloading audio in m4a format...")
        ydl_opts.update({
            'format': 'bestaudio[ext!=m4a]',
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'm4a',
                'preferredquality': '256',
            }],
            'postprocessor_args': {
                'extractaudio': ['-c:a', 'aac', '-b:a', '256k'],
            },
        })
    elif file_type == 'mp3':
        print("Downloading audio in mp3 format...")
        ydl_opts.update({
            'format': 'bestaudio/best',
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '256',
            }],
        })
    elif file_type == 'fhd':
        print("Downloading video in FHD format...")
        ydl_opts.update({
            'format': 'bestvideo[ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a][acodec^=mp4a]/best[ext=mp4]',
            'format_sort': ['res:1080', 'vcodec:h264'],
            'merge_output_format': 'mp4',
        })
    elif file_type == 'uhd':
        print("Downloading video in UHD format...")
        ydl_opts.update({
            'format': 'bestvideo[height<=3840]+bestaudio/best',
            'merge_output_format': 'mp4',
        })
    else:
        ydl_opts.update({
            'format': 'bestvideo*+bestaudio/best',
            'merge_output_format': 'mp4',
        })

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Download a video using yt-dlp.')
    parser.add_argument('video_url', help='Video URL to download')
    parser.add_argument(
        '--file-type',
        choices=['m4a', 'mp3', 'fhd', 'uhd'],
        default='uhd',
        help='Output file type (default: uhd)',
    )
    args = parser.parse_args()
    download_video(args.video_url, args.file_type)
