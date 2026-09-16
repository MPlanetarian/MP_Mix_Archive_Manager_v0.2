const { exec } = require('child_process');
const { spawn } = require('child_process');
const { which } = require('path');

const DEFAULT_PLAYER = 'strawberry';

function isPlayerRunning(player) {
    try {
        const result = exec(`pgrep -f ${player}`);
        return result.stdout.trim() !== '';
    } catch (error) {
        return false;
    }
}

function launchPlayer(player) {
    if (isPlayerRunning(player)) {
        console.log(`${player} is already running, not launching a new instance.`);
        return;
    }

    const playerPath = which(player);
    if (!playerPath) {
        console.error(`Player ${player} not found.`);
        return;
    }

    const playerProcess = spawn(playerPath, [], { stdio: 'inherit' });
    playerProcess.on('close', (code) => {
        console.log(`Player ${player} exited with code ${code}`);
    });
}

function main() {
    const player = process.env.PLAYER || DEFAULT_PLAYER;
    launchPlayer(player);
}

main();
