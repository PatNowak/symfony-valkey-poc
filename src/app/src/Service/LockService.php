<?php

namespace App\Service;

use Predis\Client;
use Symfony\Component\Lock\LockFactory;
use Symfony\Component\Lock\LockInterface;
use Symfony\Component\Lock\Store\RedisStore;

class LockService
{
    private readonly LockFactory $lockFactory;

    /**
     * @var array<string,Lock\LockInterface>
     */
    private array $locks = [];

    public function __construct(private readonly Client $redis) {
        // https://symfony.com/doc/5.4/components/lock.html
        $store = new RedisStore($this->redis);
        $this->lockFactory = new LockFactory($store);
    }

    public function createAndAcquireLockWithAutoRelease(
        string $name,
        ?int $tryToAcquireSeconds = null,
        ?int $expireLockAfterSeconds = null,
    ): ?LockInterface {
        // sanity check - you are not allowed to try to hold the same lock twice in the same process
        if (array_key_exists($name, $this->locks)) {
            throw new \InvalidArgumentException('Trying to create lock with name that is already held: ' . $name);
        }

        $tryToAcquireSeconds ??= 15;
        $expireLockAfterSeconds ??= 30;

        $prefixedLockName = 'test-lock-' . $name;
        $timestampStarted = time();
        $lockAcquired = false;
        $lock = $this->lockFactory->createLock($prefixedLockName, $expireLockAfterSeconds, true);

        // try to get lock or crash - in the future we want to handle this a bit nicer
        while (!$lockAcquired) {
            // try to get the lock
            $lockAcquired = $lock->acquire();
            if ((time() - $timestampStarted) > $tryToAcquireSeconds) {
                return null;
            }

            // sleep random between 0 and 0.1 seconds to spread out requests a bit
            usleep(random_int(0, 100000));
        }

        // we have a lock to hold :)
        $this->locks[$name] = $lock;

        return $lock;
    }
}